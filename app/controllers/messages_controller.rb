class MessagesController < ApplicationController
  def create
    @conversation = Conversation.for_visitor(visitor_id).find(params[:conversation_id])
    content = params[:content].to_s.strip

    if content.blank?
      redirect_to @conversation, alert: "Message cannot be blank."
      return
    end

    @conversation.messages.create!(role: "user", content: content)
    AgentResponseJob.perform_async(@conversation.id)
    redirect_to @conversation
  end
end
