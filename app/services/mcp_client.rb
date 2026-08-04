class McpClient
  Error = Class.new(StandardError)

  TOKEN_EXPIRY_BUFFER = 60 # seconds

  @cached_token     = nil
  @token_expires_at = nil
  @token_mutex      = Mutex.new

  def self.list_tools
    response = post({ method: "tools/list", params: {}, id: 1 })
    raise Error, "tools/list failed: #{response['error']}" if response["error"]

    (response.dig("result", "tools") || []).map { |tool| to_bedrock_tool(tool) }
  end

  def self.call_tool(name, arguments)
    response = post({
      method: "tools/call",
      params: { name: name, arguments: arguments },
      id: 2,
    })

    raise Error, response.dig("error", "message") if response["error"]

    if response.dig("result", "isError")
      error_text = (response.dig("result", "content") || [])
                     .filter_map { |c| c["text"] }
                     .join("\n")
      raise Error, "Tool #{name} returned error: #{error_text}"
    end

    (response.dig("result", "content") || [])
      .filter_map { |c| c["text"] }
      .join("\n")
  end

  def self.post(body)
    conn = Faraday.new(url: mcp_url) do |f|
      f.request  :json
      f.response :json, content_type: //
      f.response :raise_error
      f.adapter  Faraday.default_adapter
    end

    headers = { "Content-Type" => "application/json", "Accept" => "application/json" }
    token   = bearer_token
    headers["Authorization"] = "Bearer #{token}" if token

    conn.post("/", body.merge(jsonrpc: "2.0").to_json, headers).body
  rescue Faraday::Error => e
    raise Error, "MCP request failed: #{e.message}"
  end
  private_class_method :post

  def self.bearer_token
    return nil unless client_id.present? && client_secret.present?

    @token_mutex.synchronize do
      if @cached_token.nil? || Time.current >= @token_expires_at
        @cached_token     = fetch_hub_token
        @token_expires_at = parse_expiry(@cached_token)
      end
    end

    @cached_token
  end
  private_class_method :bearer_token

  def self.fetch_hub_token
    conn = Faraday.new(url: hub_token_url) do |f|
      f.request  :url_encoded
      f.response :json, content_type: //
      f.response :raise_error
      f.adapter  Faraday.default_adapter
    end

    response = conn.post("", {
      grant_type: "client_credentials",
      client_id: client_id,
      client_secret: client_secret,
      scope: "tariff/read",
    })

    token = response.body["access_token"]
    raise Error, "Hub returned no access_token" unless token.present?

    token
  rescue Faraday::Error => e
    raise Error, "Hub token fetch failed: #{e.message}"
  end
  private_class_method :fetch_hub_token

  def self.parse_expiry(jwt)
    segments = jwt.to_s.split(".")
    return Time.current if segments.length < 2

    padded  = segments[1].ljust((segments[1].length + 3) & ~3, "=")
    payload = JSON.parse(Base64.urlsafe_decode64(padded))
    exp     = payload["exp"].to_i
    exp.positive? ? Time.at(exp) - TOKEN_EXPIRY_BUFFER : Time.current + 50.minutes
  rescue JSON::ParserError, ArgumentError
    Time.current + 50.minutes
  end
  private_class_method :parse_expiry

  def self.to_bedrock_tool(tool)
    schema = tool["inputSchema"] || tool["input_schema"] || {}
    {
      tool_spec: {
        name: tool["name"],
        description: tool["description"],
        input_schema: { json: deep_symbolize(schema) },
      },
    }
  end
  private_class_method :to_bedrock_tool

  def self.deep_symbolize(obj)
    case obj
    when Hash  then obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
    when Array then obj.map { |v| deep_symbolize(v) }
    else obj
    end
  end
  private_class_method :deep_symbolize

  def self.mcp_url
    ENV.fetch("MCP_URL", "http://localhost:3000")
  end
  private_class_method :mcp_url

  def self.client_id
    ENV.fetch("MCP_CLIENT_ID", nil)
  end
  private_class_method :client_id

  def self.client_secret
    ENV.fetch("MCP_CLIENT_SECRET", nil)
  end
  private_class_method :client_secret

  def self.hub_token_url
    ENV.fetch("MCP_HUB_TOKEN_URL", "https://auth.id.trade-tariff.service.gov.uk/oauth2/token")
  end
  private_class_method :hub_token_url
end
