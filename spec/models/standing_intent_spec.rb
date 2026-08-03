require "rails_helper"

RSpec.describe StandingIntent, type: :model do
  it { is_expected.to validate_presence_of(:visitor_id) }
  it { is_expected.to validate_presence_of(:commodity_code) }
  it { is_expected.to validate_presence_of(:description) }
  it { is_expected.to validate_presence_of(:original_request) }

  describe "#needs_check?" do
    subject(:intent) { build(:standing_intent, last_checked_at: last_checked_at) }

    context "when never checked" do
      let(:last_checked_at) { nil }
      it { is_expected.to be_needs_check }
    end

    context "when checked more than 6 hours ago" do
      let(:last_checked_at) { 7.hours.ago }
      it { is_expected.to be_needs_check }
    end

    context "when checked less than 6 hours ago" do
      let(:last_checked_at) { 1.hour.ago }
      it { is_expected.not_to be_needs_check }
    end
  end
end
