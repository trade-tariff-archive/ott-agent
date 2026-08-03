class StandingIntentCheckJob
  include Sidekiq::Job

  DIFF_WINDOW_DAYS = 30

  def perform
    StandingIntent.due_for_check.find_each do |intent|
      check_intent(intent)
    rescue StandardError => e
      Rails.logger.error("StandingIntentCheckJob: failed for intent #{intent.id}: #{e.message}")
    end
  end

  private

  def check_intent(intent)
    diff_text  = McpClient.call_tool("commodity_history_diff", {
      "commodity_code" => intent.commodity_code,
      "days"           => DIFF_WINDOW_DAYS
    })
    new_digest = Digest::SHA256.hexdigest(diff_text)
    changed    = new_digest != intent.last_result_digest

    intent.update!(last_checked_at: Time.current, last_result_digest: new_digest)

    return unless changed

    summarise_change(intent, diff_text)
  end

  def summarise_change(intent, diff_text)
    conversation = Conversation.create!(
      visitor_id: intent.visitor_id,
      title:      "Alert: #{intent.description}"
    )

    prompt = <<~PROMPT
      A standing tariff alert has triggered for: #{intent.description}

      The following changes were detected for commodity #{intent.commodity_code}:
      #{diff_text}

      Please summarise what changed and what it means for an importer or exporter.
      Be concise (2-3 sentences).
    PROMPT

    conversation.messages.create!(role: "user", content: prompt)
    message = AgentService.respond(conversation, model: AgentService::SCHEDULED_MODEL)
    Rails.logger.info("StandingIntentCheckJob: alert for intent #{intent.id}: #{message.content.truncate(100)}")
  end
end
