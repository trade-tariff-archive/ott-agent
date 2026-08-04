class StandingIntentsController < ApplicationController
  def index
    @intents = StandingIntent.active.for_visitor(visitor_id).order(created_at: :desc)
  end

  def new
    @intent = StandingIntent.new
  end

  def create
    if params[:request_text].blank?
      redirect_to standing_intents_path, alert: "Please enter a commodity description." and return
    end

    parsed = IntentParserService.parse(params[:request_text])

    @intent = StandingIntent.new(
      visitor_id: visitor_id,
      commodity_code: parsed[:commodity_code],
      description: parsed[:description],
      original_request: params[:request_text],
    )

    if @intent.save
      redirect_to standing_intents_path, notice: "Alert saved. You'll be notified when data changes."
    else
      render :new, status: :unprocessable_entity
    end
  rescue IntentParserService::ParseError, Aws::BedrockRuntime::Errors::ServiceError => e
    flash.now[:alert] = "Could not identify a commodity: #{e.message}"
    @intent = StandingIntent.new
    render :new, status: :unprocessable_entity
  end

  def destroy
    StandingIntent.for_visitor(visitor_id).find(params[:id]).update!(active: false)
    redirect_to standing_intents_path, notice: "Alert removed."
  end
end
