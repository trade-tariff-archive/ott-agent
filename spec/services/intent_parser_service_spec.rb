require "rails_helper"

RSpec.describe IntentParserService do
  describe ".parse" do
    let(:mock_response) do
      double(
        stop_reason: "end_turn",
        output: double(
          message: double(
            content: [
              double(
                text: '{"commodity_code":"0101210000","description":"Monitor duty rate changes on live horses"}',
                tool_use: nil
              )
            ]
          )
        ),
        usage: double(input_tokens: 100, output_tokens: 30)
      )
    end

    before do
      allow(BedrockClient).to receive(:converse).and_return(mock_response)
    end

    it "returns a hash with commodity_code and description" do
      result = IntentParserService.parse("Alert me if the duty on 0101210000 changes")

      expect(result[:commodity_code]).to eq("0101210000")
      expect(result[:description]).to be_a(String)
      expect(result[:description]).not_to be_empty
    end

    context "when the LLM returns non-parseable text" do
      let(:mock_response) do
        double(
          stop_reason: "end_turn",
          output: double(
            message: double(
              content: [double(text: "I cannot identify a commodity code.", tool_use: nil)]
            )
          ),
          usage: double(input_tokens: 50, output_tokens: 10)
        )
      end

      it "raises IntentParserService::ParseError" do
        expect {
          IntentParserService.parse("Watch the weather for me")
        }.to raise_error(IntentParserService::ParseError)
      end
    end
  end
end
