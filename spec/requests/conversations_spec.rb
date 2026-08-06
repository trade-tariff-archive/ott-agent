require "rails_helper"

RSpec.describe "Conversations", type: :request do
  let(:auth_headers) do
    password = ENV.fetch("APP_PASSWORD", "dev123")
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("x", password)
    { "HTTP_AUTHORIZATION" => credentials }
  end

  describe "GET /conversations/:id" do
    let(:visitor_a_id) { SecureRandom.uuid }
    let(:visitor_b_id) { SecureRandom.uuid }
    let!(:conversation) { Conversation.create!(visitor_id: visitor_a_id, title: "A's convo") }

    it "allows the owner to view their conversation" do
      allow_any_instance_of(ApplicationController).to receive(:visitor_id).and_return(visitor_a_id)
      get conversation_path(conversation), headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a different visitor's conversation" do
      allow_any_instance_of(ApplicationController).to receive(:visitor_id).and_return(visitor_b_id)
      get conversation_path(conversation), headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
