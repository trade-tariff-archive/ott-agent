require "rails_helper"

RSpec.describe Message, type: :model do
  it { is_expected.to belong_to(:conversation) }
  it { is_expected.to validate_presence_of(:role) }
  it { is_expected.to validate_inclusion_of(:role).in_array(%w[user assistant]) }
  it { is_expected.to validate_presence_of(:content) }
end
