class AgentService
  INTERACTIVE_MODEL   = "eu.anthropic.claude-sonnet-4-5-20251001-v1:0"
  SCHEDULED_MODEL     = "eu.anthropic.claude-haiku-4-5-20251001-v1:0"
  MAX_TOOL_ITERATIONS = 10

  SYSTEM_PROMPT = [
    {
      text: <<~PROMPT.freeze
        You are a UK trade tariff assistant. You help users find commodity codes, understand
        import and export duties, VAT, quotas, rules of origin, and related tariff information
        for goods traded with the UK and Northern Ireland.

        You have access to the Trade Tariff MCP tools. Always use them to look up accurate,
        current data rather than relying on your training knowledge. If a user asks about
        something unrelated to trade tariffs or customs, politely explain that you can only
        help with tariff-related queries.

        Be concise and accurate. Where relevant, cite the commodity code and duty rates you
        found. If a code is ambiguous, use classification_search first.
      PROMPT
    }
  ].freeze

  # Creates the user message then delegates to respond.
  # Use this from the benchmark script and intent parser (callers that haven't saved the user message).
  def self.run(conversation, user_content, model: INTERACTIVE_MODEL)
    conversation.messages.create!(role: "user", content: user_content)
    respond(conversation, model: model)
  end

  # Processes the existing conversation history and creates the assistant message.
  # Use this from AgentResponseJob (controller has already saved the user message).
  def self.respond(conversation, model: INTERACTIVE_MODEL)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    tools    = McpClient.list_tools
    messages = build_messages(conversation)

    total_input_tokens  = 0
    total_output_tokens = 0

    reached_end_turn = false

    MAX_TOOL_ITERATIONS.times do
      response = BedrockClient.converse(
        model_id:         model,
        system:           SYSTEM_PROMPT,
        messages:         messages,
        tool_config:      { tools: tools },
        inference_config: { max_tokens: 4096 }
      )

      total_input_tokens  += response.usage.input_tokens.to_i
      total_output_tokens += response.usage.output_tokens.to_i

      assistant_content = response.output.message.content

      messages << { role: "assistant", content: content_to_converse(assistant_content) }

      if response.stop_reason == "end_turn"
        reached_end_turn = true
        break
      end

      tool_results = assistant_content
        .select { |block| block.tool_use }
        .map do |block|
          result = McpClient.call_tool(block.tool_use.name, block.tool_use.input)
          {
            tool_result: {
              tool_use_id: block.tool_use.tool_use_id,
              content:     [{ text: result }]
            }
          }
        end

      messages << { role: "user", content: tool_results }
    end

    final_text = if reached_end_turn
      extract_text(messages.last[:content])
    else
      last_assistant_content = messages.reverse.find { |m| m[:role] == "assistant" }&.dig(:content) || []
      extracted = extract_text(last_assistant_content)
      extracted.present? ? "#{extracted}\n\n[Response truncated: maximum tool iterations reached]" : "[Response truncated: maximum tool iterations reached without a final response]"
    end
    latency    = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    conversation.messages.create!(
      role:            "assistant",
      content:         final_text,
      input_tokens:    total_input_tokens,
      output_tokens:   total_output_tokens,
      latency_seconds: latency
    )
  end

  def self.build_messages(conversation)
    conversation.messages.order(:created_at).map do |msg|
      {
        role:    msg.role,
        content: [{ text: msg.content }]
      }
    end
  end
  private_class_method :build_messages

  def self.content_to_converse(content_blocks)
    content_blocks.map do |block|
      if block.tool_use
        {
          tool_use: {
            tool_use_id: block.tool_use.tool_use_id,
            name:        block.tool_use.name,
            input:       block.tool_use.input
          }
        }
      else
        { text: block.text.to_s }
      end
    end
  end
  private_class_method :content_to_converse

  def self.extract_text(content)
    return content.to_s if content.is_a?(String)

    Array(content)
      .filter_map { |block| block[:text] if block.is_a?(Hash) }
      .join("\n")
  end
  private_class_method :extract_text
end
