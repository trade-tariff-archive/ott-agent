# ott-agent/spec/services/mcp_client_spec.rb
require "rails_helper"

RSpec.describe McpClient do
  let(:hub_token_url) { "https://hub.example.com/oauth2/token" }
  let(:mcp_url)       { "https://mcp.example.com" }
  let(:jwt_token)     { build_jwt(exp: 1.hour.from_now) }

  before do
    stub_const("ENV", ENV.to_h.merge(
                        "MCP_URL" => mcp_url,
                        "MCP_CLIENT_ID" => "test-client-id",
                        "MCP_CLIENT_SECRET" => "test-client-secret",
                        "MCP_HUB_TOKEN_URL" => hub_token_url,
                      ))
    McpClient.instance_variable_set(:@cached_token, nil)
    McpClient.instance_variable_set(:@token_expires_at, nil)
  end

  def build_jwt(exp:)
    payload = Base64.urlsafe_encode64({ exp: exp.to_i }.to_json, padding: false)
    "header.#{payload}.sig"
  end

  def stub_token_request(token: jwt_token)
    stub_request(:post, hub_token_url)
      .with(body: hash_including("grant_type" => "client_credentials"))
      .to_return(
        status: 200,
        body: { access_token: token }.to_json,
        headers: { "Content-Type" => "application/json" },
      )
  end

  describe ".list_tools" do
    before do
      stub_token_request
      stub_request(:post, "#{mcp_url}/")
        .with(
          headers: { "Authorization" => "Bearer #{jwt_token}" },
          body: hash_including("method" => "tools/list"),
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            jsonrpc: "2.0",
            id: 1,
            result: {
              tools: [
                {
                  name: "lookup_commodity",
                  description: "Performs commodity lookup",
                  inputSchema: {
                    type: "object",
                    properties: { commodity_code: { type: "string" } },
                    required: %w[commodity_code],
                  },
                },
              ],
            },
          }.to_json,
        )
    end

    it "fetches a token from Hub and returns tools in Bedrock Converse format" do
      tools = McpClient.list_tools

      expect(tools.length).to eq(1)
      expect(tools.first[:tool_spec][:name]).to eq("lookup_commodity")
      expect(tools.first[:tool_spec][:input_schema][:json][:type]).to eq("object")
    end

    it "reuses a cached token without calling Hub again" do
      McpClient.list_tools
      McpClient.list_tools

      expect(WebMock).to have_requested(:post, hub_token_url).once
    end

    it "re-fetches the token when the cached one has expired" do
      expired_jwt = build_jwt(exp: 1.minute.ago)
      McpClient.instance_variable_set(:@cached_token, expired_jwt)
      McpClient.instance_variable_set(:@token_expires_at, 1.minute.ago)

      stub_token_request
      stub_request(:post, "#{mcp_url}/").to_return(
        status: 200,
        body: { jsonrpc: "2.0", id: 1, result: { tools: [] } }.to_json,
        headers: { "Content-Type" => "application/json" },
      )

      McpClient.list_tools
      expect(WebMock).to have_requested(:post, hub_token_url).once
    end

    context "when the MCP server returns a JSON-RPC error" do
      before do
        stub_request(:post, "#{mcp_url}/")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { jsonrpc: "2.0", id: 1, error: { code: -32_603, message: "Internal server error" } }.to_json,
          )
      end

      it "raises McpClient::Error instead of returning an empty tool list" do
        expect { McpClient.list_tools }
          .to raise_error(McpClient::Error, /tools\/list failed/)
      end
    end
  end

  describe ".call_tool" do
    before do
      stub_token_request
      stub_request(:post, "#{mcp_url}/")
        .with(body: hash_including("method" => "tools/call"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            jsonrpc: "2.0",
            id: 2,
            result: { content: [{ type: "text", text: "Commodity: Live horses\nDuty rate: 0%" }] },
          }.to_json,
        )
    end

    it "returns the text content from the MCP tool result" do
      result = McpClient.call_tool("lookup_commodity", { commodity_code: "0101210000" })
      expect(result).to eq("Commodity: Live horses\nDuty rate: 0%")
    end

    context "when the MCP server returns a JSON-RPC error" do
      before do
        stub_request(:post, "#{mcp_url}/")
          .to_return(
            status: 200,
            body: { jsonrpc: "2.0", id: 2, error: { code: -32_602, message: "Invalid params" } }.to_json,
          )
      end

      it "raises McpClient::Error" do
        expect { McpClient.call_tool("lookup_commodity", {}) }
          .to raise_error(McpClient::Error, "Invalid params")
      end
    end

    context "when the tool result has isError set" do
      before do
        stub_token_request
        stub_request(:post, "#{mcp_url}/")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              jsonrpc: "2.0",
              id: 2,
              result: {
                isError: true,
                content: [{ type: "text", text: "commodity_code not found" }],
              },
            }.to_json,
          )
      end

      it "raises McpClient::Error with the tool error message" do
        expect { McpClient.call_tool("lookup_commodity", { "commodity_code" => "9999999999" }) }
          .to raise_error(McpClient::Error, /lookup_commodity returned error.*commodity_code not found/m)
      end
    end
  end
end
