require "rails_helper"

RSpec.describe Conversation, type: :model do
  it { is_expected.to have_many(:messages).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:visitor_id) }

  describe "#total_tokens" do
    let(:conversation) { create(:conversation) }

    before do
      create(:message, conversation: conversation, input_tokens: 100, output_tokens: 50)
      create(:message, conversation: conversation, input_tokens: 200, output_tokens: 80)
    end

    it "sums all input and output tokens across messages" do
      expect(conversation.total_tokens).to eq(430)
    end
  end
end
