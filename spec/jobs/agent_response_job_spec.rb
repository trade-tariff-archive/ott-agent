require "rails_helper"

RSpec.describe AgentResponseJob, type: :job do
  let(:conversation) { create(:conversation) }

  before do
    create(:message, conversation: conversation, role: "user",
           content: "What is the duty on 0101210000?")
  end

  describe "#perform" do
    it "calls AgentService.respond with the conversation" do
      allow(AgentService).to receive(:respond).and_return(
        build(:message, role: "assistant", content: "0%")
      )

      described_class.new.perform(conversation.id)

      expect(AgentService).to have_received(:respond).with(conversation)
    end

    it "does not raise for an unknown conversation_id (error is logged)" do
      expect(Rails.logger).to receive(:error).with(/999999/)
      expect { described_class.new.perform(999_999) }.not_to raise_error
    end

    context "when AgentService.respond raises" do
      it "creates an error assistant message on the conversation" do
        allow(AgentService).to receive(:respond).and_raise(StandardError, "Bedrock throttled")

        expect {
          described_class.new.perform(conversation.id)
        }.to change { conversation.messages.count }.by(1)

        error_message = conversation.messages.order(:created_at).last
        expect(error_message.role).to eq("assistant")
        expect(error_message.content).to include("couldn't complete that request")
      end
    end
  end
end
