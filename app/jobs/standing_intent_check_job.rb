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
    current_data = fetch_current_data(intent)
    new_digest   = Digest::SHA256.hexdigest(current_data)
    changed      = new_digest != intent.last_result_digest

    intent.update!(last_checked_at: Time.current, last_result_digest: new_digest)

    return unless changed

    summarise_change(intent, current_data)
  end

  def fetch_current_data(intent)
    if intent.commodity_code.start_with?("FREE:")
      fetch_free_text_status(intent)
    elsif intent.commodity_code.start_with?("QUOTA:")
      quota_number = intent.commodity_code.delete_prefix("QUOTA:")
      McpClient.call_tool("search_quotas", { "quota_search_reference" => quota_number })
    else
      McpClient.call_tool("commodity_history_diff", {
        "commodity_code" => intent.commodity_code,
        "from_date"      => DIFF_WINDOW_DAYS.days.ago.to_date.to_s
      })
    end
  end

  def fetch_free_text_status(intent)
    conversation = Conversation.create!(
      visitor_id: intent.visitor_id,
      title:      "Status check (internal)"
    )
    prompt = <<~PROMPT
      Using the trade tariff tools, produce a concise factual status summary for the
      following monitoring topic: #{intent.description}

      Include specific commodity codes, duty rates, quota utilisation percentages, or other
      concrete numbers where relevant. Format as bullet points. Be precise — the output will
      be used to detect changes over time.
    PROMPT
    message = AgentService.run(conversation, prompt, model: AgentService::SCHEDULED_MODEL)
    conversation.destroy!
    message.content
  end

  def summarise_change(intent, current_data)
    conversation = Conversation.create!(
      visitor_id: intent.visitor_id,
      title:      "Alert: #{intent.description}"
    )

    subject = case
    when intent.commodity_code.start_with?("QUOTA:") then "quota #{intent.commodity_code.delete_prefix('QUOTA:')}"
    when intent.commodity_code.start_with?("FREE:")  then intent.description
    else "commodity #{intent.commodity_code}"
    end

    prompt = <<~PROMPT
      A standing tariff alert has triggered for: #{intent.description}

      The following data was retrieved for #{subject}:
      #{current_data}

      Please summarise what changed and what it means for an importer or exporter.
      Be concise (2-3 sentences).
    PROMPT

    conversation.messages.create!(role: "user", content: prompt)
    message = AgentService.respond(conversation, model: AgentService::SCHEDULED_MODEL)
    Rails.logger.info("StandingIntentCheckJob: alert for intent #{intent.id}: #{message.content.truncate(100)}")
  end
end
