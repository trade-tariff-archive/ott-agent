class ConversationsController < ApplicationController
  def index
    @conversations = Conversation.for_visitor(visitor_id).order(created_at: :desc).includes(:messages)
  end

  def show
    @conversation = Conversation.for_visitor(visitor_id).find_by(id: params[:id])
    return head :not_found unless @conversation

    @messages = @conversation.messages.order(:created_at)
  end

  def create
    first_message = params[:title].to_s.strip

    @conversation = Conversation.new(
      visitor_id: visitor_id,
      title: first_message.presence || "New conversation",
    )

    if @conversation.save
      if first_message.present?
        @conversation.messages.create!(role: "user", content: first_message)
        AgentResponseJob.perform_async(@conversation.id)
      end
      redirect_to @conversation
    else
      redirect_to conversations_path, alert: "Could not create conversation."
    end
  end
end
