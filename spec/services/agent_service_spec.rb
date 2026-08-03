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
            required: ["commodity_code"]
          }
        }
      }
    }]
  end

  let(:end_turn_response) do
    double(
      stop_reason: "end_turn",
      output: double(
        message: double(
          content: [double(text: "The duty rate is 0%.", tool_use: nil)]
        )
      ),
      usage: double(input_tokens: 150, output_tokens: 20)
    )
  end

  before do
    allow(McpClient).to receive(:list_tools).and_return(mcp_tools)
    allow(BedrockClient).to receive(:converse).and_return(end_turn_response)
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
    end

    context "when the model makes a tool call" do
      let(:tool_use_block) do
        double(
          text: nil,
          tool_use: double(
            tool_use_id: "tool_1",
            name: "lookup_commodity",
            input: { "commodity_code" => "0101210000" }
          )
        )
      end

      let(:tool_use_response) do
        double(
          stop_reason: "tool_use",
          output: double(message: double(content: [tool_use_block])),
          usage: double(input_tokens: 200, output_tokens: 30)
        )
      end

      before do
        allow(BedrockClient).to receive(:converse)
          .and_return(tool_use_response, end_turn_response)
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
    end

    context "when MAX_TOOL_ITERATIONS is reached without end_turn" do
      let(:tool_use_block) do
        double(
          text: nil,
          tool_use: double(
            tool_use_id: "tool_forever",
            name: "lookup_commodity",
            input: { "commodity_code" => "0101210000" }
          )
        )
      end

      let(:always_tool_use_response) do
        double(
          stop_reason: "tool_use",
          output: double(message: double(content: [tool_use_block])),
          usage: double(input_tokens: 10, output_tokens: 5)
        )
      end

      before do
        allow(BedrockClient).to receive(:converse).and_return(always_tool_use_response)
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
