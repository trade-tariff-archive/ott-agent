class IntentParserService
  ParseError = Class.new(StandardError)

  PARSE_PROMPT = [
    {
      text: <<~PROMPT.freeze
        Extract a standing tariff intent from the user's request. Return ONLY valid JSON with
        these exact keys:
          "commodity_code": the 10-digit commodity code (or fewer digits if that is all given)
          "description": a short human-readable description of what to monitor (max 100 chars)

        If you cannot identify a specific commodity code, return {"error": "no_commodity_code"}.
        No markdown fences, no explanation — raw JSON only.
      PROMPT
    }
  ].freeze

  def self.parse(request_text)
    response = BedrockClient.converse(
      model_id:         AgentService::SCHEDULED_MODEL,
      system:           PARSE_PROMPT,
      messages:         [{ role: "user", content: [{ text: request_text }] }],
      inference_config: { max_tokens: 256 }
    )

    text = response.output.message.content
      .find { |b| b.text }
      &.text
      .to_s.strip

    data = JSON.parse(text)
    raise ParseError, "No commodity code identified" if data["error"].present?
    raise ParseError, "Missing commodity_code"       unless data["commodity_code"].present?

    { commodity_code: data["commodity_code"], description: data["description"].to_s }
  rescue JSON::ParserError
    raise ParseError, "LLM returned non-JSON response"
  end
end
