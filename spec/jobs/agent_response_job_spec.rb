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

    it "raises ActiveRecord::RecordNotFound for an unknown conversation_id" do
      expect { described_class.new.perform(999_999) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
