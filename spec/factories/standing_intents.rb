FactoryBot.define do
  factory :standing_intent do
    visitor_id       { SecureRandom.uuid }
    commodity_code   { "0101210000" }
    description      { "Monitor duty rate changes on live horses" }
    original_request { "Alert me if the duty on 0101210000 changes" }
    last_checked_at  { nil }
    last_result_digest { nil }
    active { true }
  end
end
