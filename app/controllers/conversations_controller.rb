class ConversationsController < ApplicationController
  def index
    @conversations = Conversation.for_visitor(visitor_id).order(created_at: :desc)
  end

  def show
    @conversation = Conversation.for_visitor(visitor_id).find(params[:id])
    @messages     = @conversation.messages.order(:created_at)
  end

  def create
    @conversation = Conversation.new(
      visitor_id: visitor_id,
      title:      params[:title].presence || "New conversation"
    )

    if @conversation.save
      redirect_to @conversation
    else
      redirect_to conversations_path, alert: "Could not create conversation."
    end
  end
end
