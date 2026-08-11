class MessagesController < ApplicationController
  def create
    @conversation = Conversation.find(params[:conversation_id])

    if @conversation.messages.order(:created_at).last&.role == "user"
      head :too_many_requests and return
    end

    content = params[:content].to_s.strip

    if content.blank?
      redirect_to @conversation, alert: "Message cannot be blank."
      return
    end

    @conversation.messages.create!(role: "user", content: content)
    AgentResponseJob.perform_async(@conversation.id)

    respond_to do |format|
      format.turbo_stream do
        user_html = <<~HTML
          <div class="govuk-inset-text govuk-!-margin-bottom-3">
            <p class="govuk-caption-m govuk-!-margin-bottom-1">You</p>
            <div class="app-message-content">#{ERB::Util.h(content)}</div>
          </div>
        HTML

        pending_html = <<~HTML
          <div id="assistant-response-pending" class="govuk-inset-text govuk-!-margin-bottom-3">
            <p class="govuk-caption-m govuk-!-margin-bottom-1">Assistant</p>
            <div id="streaming-message-content" class="app-message-content">
              <p class="govuk-body govuk-hint app-thinking">Thinking<span class="app-thinking__dots"><span>.</span><span>.</span><span>.</span></span></p>
            </div>
          </div>
        HTML

        render turbo_stream: [
          turbo_stream.before("messages-bottom", html: user_html.html_safe),
          turbo_stream.before("messages-bottom", html: pending_html.html_safe),
        ]
      end
      format.html { redirect_to @conversation }
    end
  end
end
