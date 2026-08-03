FactoryBot.define do
  factory :conversation do
    visitor_id { SecureRandom.uuid }
    sequence(:title) { |n| "Conversation #{n}" }
  end
end
