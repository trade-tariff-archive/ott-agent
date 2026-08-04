class IntentParserService
  ParseError = Class.new(StandardError)

  PARSE_PROMPT = [
    {
      text: <<~PROMPT.freeze
        Extract a standing tariff alert intent from the user's request.

        Return ONLY valid JSON with these exact keys:
          "type": one of "commodity", "quota", or "free_text"
          "identifier": for commodity — the commodity code (10 digits or fewer);
                        for quota — the quota order number (e.g. "050001");
                        for free_text — omit this key or set null
          "description": a short human-readable description of what to monitor (max 100 chars)

        Use "free_text" when the request is a valid tariff-related monitoring request but
        cannot be tied to a specific commodity code or quota number (e.g. "alert me if any
        new anti-dumping duties are introduced on steel products").

        If the request has nothing to do with trade or tariffs, return {"error": "not_trade_related"}.
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
      .gsub(/\A```(?:json)?\s*/, "")
      .gsub(/\s*```\z/, "")
      .strip

    data = JSON.parse(text)
    raise ParseError, "Not a trade-related request" if data["error"].present?

    stored_code = case data["type"]
    when "quota"     then "QUOTA:#{data['identifier']}"
    when "free_text" then "FREE:#{data['description']}"
    else
      raise ParseError, "Missing commodity code" unless data["identifier"].present?
      data["identifier"]
    end

    { commodity_code: stored_code, description: data["description"].to_s }
  rescue JSON::ParserError
    raise ParseError, "LLM returned non-JSON response"
  end
end
