require "rails_helper"

RSpec.describe AgentService do
  let(:visitor_id)   { SecureRandom.uuid }
  let(:conversation) { create(:conversation, visitor_id: visitor_id) }

  let(:mcp_tools) do
    [{
      tool_spec: {
        name: "lookup_commodity",
        description: "Look up a commodity",
        input_schema: {
          json: {
            type: "object",
            properties: { commodity_code: { type: "string" } },
            required: %w[commodity_code],
          },
        },
      },
    }]
  end

  # Stubs BedrockClient.converse_stream to behave as a single end_turn response
  # that streams the given text then stops.
  def stub_end_turn_stream(text:, input_tokens: 150, output_tokens: 20)
    allow(BedrockClient).to receive(:converse_stream) do |**_params, &block|
      stream = FakeConverseStream.new
      block.call(stream)
      stream.emit_text_delta(text)
      stream.emit_metadata(input_tokens: input_tokens, output_tokens: output_tokens)
      stream.emit_message_stop(stop_reason: "end_turn")
    end
  end

  before do
    allow(McpClient).to receive(:list_tools).and_return(mcp_tools)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    stub_end_turn_stream(text: "The duty rate is 0%.")
  end

  describe ".run" do
    it "creates a user message then returns an assistant message" do
      expect { AgentService.run(conversation, "What is the duty on 0101210000?") }
        .to change { conversation.messages.count }.by(2)
    end

    it "creates the user message with the given content" do
      AgentService.run(conversation, "What is the duty on 0101210000?")
      expect(conversation.messages.find_by(role: "user").content)
        .to eq("What is the duty on 0101210000?")
    end
  end

  describe ".respond" do
    before do
      create(:message, conversation: conversation, role: "user",
                       content: "What is the duty on 0101210000?")
    end

    context "when the model returns end_turn immediately (no tool calls)" do
      it "saves and returns an assistant message" do
        message = AgentService.respond(conversation)

        expect(message).to be_a(Message)
        expect(message.role).to eq("assistant")
        expect(message.content).to eq("The duty rate is 0%.")
        expect(message.input_tokens).to eq(150)
        expect(message.output_tokens).to eq(20)
      end

      it "creates only the assistant message (user message already exists)" do
        expect { AgentService.respond(conversation) }
          .to change { conversation.messages.count }.by(1)
      end

      it "broadcasts streaming text to the conversation" do
        AgentService.respond(conversation)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to)
          .with(conversation, target: "streaming-message-content", html: anything)
          .at_least(:once)
      end

      it "clears the agent status when done" do
        AgentService.respond(conversation)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to)
          .with(conversation, target: "agent-status", html: "")
      end
    end

    context "when the model makes a tool call" do
      before do
        allow(BedrockClient).to receive(:converse_stream) do |**_params, &block|
          if @tool_call_done
            # second call: end_turn stream
            stream = FakeConverseStream.new
            block.call(stream)
            stream.emit_text_delta("The duty rate is 0%.")
            stream.emit_metadata(input_tokens: 200, output_tokens: 30)
            stream.emit_message_stop(stop_reason: "end_turn")
          else
            # first call: tool_use stream
            @tool_call_done = true
            stream = FakeConverseStream.new
            block.call(stream)
            stream.emit_tool_start(tool_use_id: "tool_1", name: "lookup_commodity", index: 0)
            stream.emit_tool_input_delta(json: '{"commodity_code":"0101210000"}', index: 0)
            stream.emit_metadata(input_tokens: 150, output_tokens: 20)
            stream.emit_message_stop(stop_reason: "tool_use")
          end
        end

        allow(McpClient).to receive(:call_tool)
          .with("lookup_commodity", { "commodity_code" => "0101210000" })
          .and_return("Commodity: Live horses. Basic duty rate: 0%.")
      end

      it "calls the MCP tool and returns the final answer" do
        message = AgentService.respond(conversation)
        expect(message.content).to eq("The duty rate is 0%.")
        expect(McpClient).to have_received(:call_tool).once
      end

      it "accumulates token usage across all turns" do
        message = AgentService.respond(conversation)
        expect(message.input_tokens).to eq(350)
        expect(message.output_tokens).to eq(50)
      end

      it "broadcasts the final message to replace the streaming placeholder" do
        AgentService.respond(conversation)
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
          .with(conversation, target: "assistant-response-pending", html: anything)
      end
    end

    context "when MAX_TOOL_ITERATIONS is reached without end_turn" do
      before do
        allow(BedrockClient).to receive(:converse_stream) do |**_params, &block|
          stream = FakeConverseStream.new
          block.call(stream)
          stream.emit_tool_start(tool_use_id: "tool_forever", name: "lookup_commodity", index: 0)
          stream.emit_tool_input_delta(json: '{"commodity_code":"0101210000"}', index: 0)
          stream.emit_metadata(input_tokens: 10, output_tokens: 5)
          stream.emit_message_stop(stop_reason: "tool_use")
        end

        allow(McpClient).to receive(:call_tool).and_return("some result")
      end

      it "saves a non-empty assistant message with a truncation notice" do
        message = AgentService.respond(conversation)
        expect(message.role).to eq("assistant")
        expect(message.content).not_to be_empty
        expect(message.content).to include("maximum tool iterations")
      end
    end
  end
end
