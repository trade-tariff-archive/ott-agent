FactoryBot.define do
  factory :message do
    conversation
    role { "user" }
    content { "What is the duty rate for commodity 0101210000?" }
    input_tokens  { 0 }
    output_tokens { 0 }
  end
end
