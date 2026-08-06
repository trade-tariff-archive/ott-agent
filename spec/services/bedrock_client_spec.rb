require "rails_helper"

RSpec.describe BedrockClient do
  let(:mock_client) { instance_double(Aws::BedrockRuntime::Client) }

  before do
    BedrockClient.instance_variable_set(:@client, nil)
    allow(Aws::BedrockRuntime::Client).to receive(:new).and_return(mock_client)
  end

  describe ".converse" do
    let(:mock_response) do
      double(
        output: double(
          message: double(
            role: "assistant",
            content: [double(text: "Hi there!", tool_use: nil)],
          ),
        ),
        stop_reason: "end_turn",
        usage: double(input_tokens: 10, output_tokens: 5),
      )
    end

    before do
      allow(mock_client).to receive(:converse).and_return(mock_response)
    end

    it "delegates to the AWS SDK converse method" do
      result = BedrockClient.converse(
        model_id: "eu.anthropic.claude-haiku-4-5-20251001-v1:0",
        messages: [{ role: "user", content: [{ text: "Hello" }] }],
        inference_config: { max_tokens: 256 },
      )

      expect(result.stop_reason).to eq("end_turn")
      expect(result.usage.input_tokens).to eq(10)
    end
  end

  describe ".converse_stream" do
    it "delegates to the AWS SDK converse_stream method with the given block" do
      yielded_block = nil
      allow(mock_client).to receive(:converse_stream) { |**_params, &block| yielded_block = block }

      sentinel = Object.new
      BedrockClient.converse_stream(
        model_id: "eu.anthropic.claude-haiku-4-5-20251001-v1:0",
        messages: [{ role: "user", content: [{ text: "Hello" }] }],
        inference_config: { max_tokens: 256 },
      ) { |stream| stream }

      expect(mock_client).to have_received(:converse_stream)
    end
  end
end
