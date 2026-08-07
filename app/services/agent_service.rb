class AgentService
  INTERACTIVE_MODEL   = "anthropic.claude-sonnet-4-6".freeze
  SCHEDULED_MODEL     = "eu.anthropic.claude-haiku-4-5-20251001-v1:0".freeze
  MAX_TOOL_ITERATIONS = 10
  STREAM_FLUSH_INTERVAL = 0.15 # seconds between progressive broadcasts

  SYSTEM_PROMPT = [
    {
      text: <<~PROMPT.freeze,
        You are a UK trade tariff assistant. You help users find commodity codes, understand
        import and export duties, VAT, quotas, rules of origin, and related tariff information
        for goods traded with the UK and Northern Ireland.

        You have access to the Trade Tariff MCP tools. Always use them to look up accurate,
        current data rather than relying on your training knowledge.

        IMPORTANT — scope constraint: you may only answer questions directly related to UK
        trade, customs, and tariffs. This includes commodity codes, import/export duties, VAT
        on imports, rules of origin, trade quotas, licences, certificates, anti-dumping
        measures, and sanctions. If a user asks about anything outside this scope — including
        general knowledge, coding, writing, or any other topic — decline politely and ask
        them to rephrase as a trade or tariff question. Do not answer off-topic questions
        even if they seem harmless.

        Tone and style:
        - Write in plain English following GOV.UK content design principles.
        - Be direct, factual and impartial. Avoid jargon where a simpler word exists.
        - Do not use emoji under any circumstances.
        - Use active voice where possible.
        - Address the user as "you".

        Be concise and accurate. Where relevant, cite the commodity code and duty rates you
        found. If a code is ambiguous, use classification_search first.

        You may use Mermaid diagrams, but only when the user explicitly asks for a chart,
        diagram, or visual. Do not produce diagrams unprompted. When asked, use a fenced
        code block tagged "mermaid".
      PROMPT
    },
  ].freeze

  # Creates the user message then delegates to respond.
  # Use this from the benchmark script and intent parser (callers that haven't saved the user message).
  def self.run(conversation, user_content, model: INTERACTIVE_MODEL)
    conversation.messages.create!(role: "user", content: user_content)
    respond(conversation, model: model)
  end

  # Processes the existing conversation history and streams the assistant response.
  # Use this from AgentResponseJob (controller has already saved the user message).
  def self.respond(conversation, model: INTERACTIVE_MODEL)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    tools    = McpClient.list_tools
    messages = build_messages(conversation)

    total_input_tokens  = 0
    total_output_tokens = 0
    reached_end_turn    = false
    final_text          = nil

    MAX_TOOL_ITERATIONS.times do
      current_text    = +""
      tool_use_blocks = {}   # content_block_index => { tool_use_id:, name:, input_json: }
      stop_reason     = nil
      last_broadcast  = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      BedrockClient.converse_stream(
        model_id: model,
        system: SYSTEM_PROMPT,
        messages: messages,
        tool_config: { tools: tools },
        inference_config: { max_tokens: 4096 },
      ) do |stream|
        stream.on_content_block_start_event do |event|
          next unless event.start.tool_use

          tool = event.start.tool_use
          tool_use_blocks[event.content_block_index] = {
            tool_use_id: tool.tool_use_id,
            name:        tool.name,
            input_json:  +"",
          }
        end

        stream.on_content_block_delta_event do |event|
          delta = event.delta

          if delta.text
            current_text << delta.text
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            if now - last_broadcast >= STREAM_FLUSH_INTERVAL
              broadcast_streaming_text(conversation, current_text)
              last_broadcast = now
            end
          elsif delta.tool_use
            tool_use_blocks[event.content_block_index][:input_json] << delta.tool_use.input
          end
        end

        stream.on_metadata_event do |event|
          total_input_tokens  += event.usage.input_tokens.to_i
          total_output_tokens += event.usage.output_tokens.to_i
        end

        stream.on_message_stop_event do |event|
          stop_reason = event.stop_reason
        end

        stream.on_error_event do |event|
          Rails.logger.error "Bedrock stream error for conversation #{conversation.id}: #{event.inspect}"
        end
      end

      broadcast_streaming_text(conversation, current_text) if current_text.present?

      assistant_content = build_streaming_content(current_text, tool_use_blocks)
      messages << { role: "assistant", content: assistant_content }

      if stop_reason == "end_turn"
        reached_end_turn = true
        final_text       = current_text
        break
      end

      tool_results = tool_use_blocks.values.map do |block|
        input = JSON.parse(block[:input_json])
        begin
          result = McpClient.call_tool(block[:name], input)
          {
            tool_result: {
              tool_use_id: block[:tool_use_id],
              content:     [{ text: result }],
            },
          }
        rescue McpClient::Error => e
          {
            tool_result: {
              tool_use_id: block[:tool_use_id],
              content:     [{ text: e.message }],
              status:      "error",
            },
          }
        end
      end

      messages << { role: "user", content: tool_results }
    end

    unless reached_end_turn
      last_assistant_content = messages.reverse.find { |m| m[:role] == "assistant" }&.dig(:content) || []
      extracted = extract_text(last_assistant_content)
      final_text = if extracted.present?
                     "#{extracted}\n\n[Response truncated: maximum tool iterations reached]"
                   else
                     "[Response truncated: maximum tool iterations reached without a final response]"
                   end
    end

    latency = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    message = conversation.messages.create!(
      role:            "assistant",
      content:         final_text,
      input_tokens:    total_input_tokens,
      output_tokens:   total_output_tokens,
      latency_seconds: latency,
    )

    broadcast_final_message(conversation, message)
    broadcast_status_clear(conversation)
    message
  end

  def self.build_messages(conversation)
    conversation.messages.order(:created_at).map do |msg|
      {
        role:    msg.role,
        content: [{ text: msg.content }],
      }
    end
  end
  private_class_method :build_messages

  def self.build_streaming_content(text, tool_use_blocks)
    content = []
    content << { text: text } if text.present?
    tool_use_blocks.each_value do |block|
      content << {
        tool_use: {
          tool_use_id: block[:tool_use_id],
          name:        block[:name],
          input:       JSON.parse(block[:input_json]),
        },
      }
    end
    content
  end
  private_class_method :build_streaming_content

  def self.extract_text(content)
    return content.to_s if content.is_a?(String)

    Array(content)
      .filter_map { |block| block[:text] if block.is_a?(Hash) }
      .join("\n")
  end
  private_class_method :extract_text

  def self.broadcast_final_message(conversation, message)
    tokens = message.input_tokens + message.output_tokens
    caption = if tokens > 0
      "Assistant · #{ActiveSupport::NumberHelper.number_to_delimited(tokens)} tokens · #{message.latency_seconds.round(1)}s"
    else
      "Assistant"
    end

    Turbo::StreamsChannel.broadcast_update_to(
      conversation,
      target: "streaming-message-content",
      html:   MarkdownRenderer.render(message.content),
    )
    Turbo::StreamsChannel.broadcast_update_to(
      conversation,
      target: "assistant-response-caption",
      html:   caption,
    )
  end

  def self.broadcast_status_clear(conversation)
    Turbo::StreamsChannel.broadcast_update_to(
      conversation,
      target: "agent-status",
      html:   "",
    )
  end

  def self.broadcast_streaming_text(conversation, text)
    Turbo::StreamsChannel.broadcast_update_to(
      conversation,
      target: "streaming-message-content",
      html:   MarkdownRenderer.render(text),
    )
  end
  private_class_method :broadcast_streaming_text
end
