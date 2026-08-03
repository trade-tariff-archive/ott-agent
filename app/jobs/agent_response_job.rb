class AgentResponseJob
  include Sidekiq::Job

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    AgentService.respond(conversation)
  end
end
