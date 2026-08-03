class AgentResponseJob
  include Sidekiq::Job
  sidekiq_options retry: 2

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    AgentService.respond(conversation)
  rescue StandardError => e
    Rails.logger.error "AgentResponseJob failed for conversation #{conversation_id}: #{e.message}"
    conversation&.messages&.create!(
      role: "assistant",
      content: "Sorry — I couldn't complete that request. Please try again.",
      input_tokens: 0,
      output_tokens: 0,
      latency_seconds: 0
    )
  end
end
