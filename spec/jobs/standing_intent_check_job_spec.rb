require "rails_helper"

RSpec.describe StandingIntentCheckJob, type: :job do
  let!(:intent) do
    create(:standing_intent, commodity_code: "0101210000",
           last_checked_at: nil, last_result_digest: nil)
  end

  let(:diff_result)         { "No changes found for 0101210000 in the last 30 days." }
  let(:changed_diff_result) { "Duty rate changed from 0% to 2.5% effective 2026-08-01." }

  before do
    allow(McpClient).to receive(:call_tool)
      .with("commodity_history_diff", hash_including("commodity_code" => "0101210000"))
      .and_return(diff_result)
  end

  describe "#perform" do
    it "updates last_checked_at on each intent" do
      expect { described_class.new.perform }
        .to change { intent.reload.last_checked_at }.from(nil)
    end

    context "when the diff result is unchanged from last time" do
      before do
        digest = Digest::SHA256.hexdigest(diff_result)
        intent.update!(last_result_digest: digest, last_checked_at: 7.hours.ago)
      end

      it "does not invoke the LLM" do
        allow(McpClient).to receive(:call_tool).and_return(diff_result)
        expect(BedrockClient).not_to receive(:converse)
        described_class.new.perform
      end
    end

    context "when the diff result has changed" do
      before do
        old_digest = Digest::SHA256.hexdigest("old content")
        intent.update!(last_result_digest: old_digest, last_checked_at: 7.hours.ago)
        allow(McpClient).to receive(:call_tool).and_return(changed_diff_result)
      end

      it "invokes AgentService to summarise the change" do
        dummy_conv = create(:conversation, visitor_id: intent.visitor_id, title: "dummy")
        allow(Conversation).to receive(:create!).and_return(dummy_conv)
        allow(AgentService).to receive(:respond).and_return(
          build(:message, role: "assistant", content: "Duty rate changed.")
        )

        described_class.new.perform

        expect(AgentService).to have_received(:respond)
      end
    end
  end
end
