class AgentResponseJob
  include Sidekiq::Job
  sidekiq_options retry: false

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    AgentService.respond(conversation)
  rescue StandardError => e
    Rails.logger.error "AgentResponseJob failed for conversation #{conversation_id}: #{e.message}"
    return unless conversation

    message = nil
    Message.suppressing_turbo_broadcasts do
      message = conversation.messages.create!(
        role: "assistant",
        content: "Sorry — I couldn't complete that request. Please try again.",
        input_tokens: 0,
        output_tokens: 0,
        latency_seconds: 0,
      )
    end
    AgentService.broadcast_final_message(conversation, message)
    AgentService.broadcast_status_clear(conversation)
  end
end
