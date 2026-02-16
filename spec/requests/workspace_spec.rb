require "rails_helper"

RSpec.describe "Workspace", type: :request do
  describe "GET /" do
    it "returns the workspace page" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Spatial Workspace")
      expect(response.body).to include("data-controller=\"workspace\"")
    end

    it "includes the three-panel layout" do
      get "/"
      expect(response.body).to include("Inbox")
      expect(response.body).to include("Workspace")
      expect(response.body).to include("Assistant")
    end
  end

  describe "GET /health" do
    it "returns health status" do
      # Allow Redis to fail in test
      allow_any_instance_of(HealthController).to receive(:redis_healthy?).and_return(true)

      get "/health"
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["status"]).to eq("ok")
      expect(body).to have_key("timestamp")
    end
  end

  describe "POST /api/command" do
    it "queues a command for the assistant" do
      expect {
        post "/api/command", params: { text: "/ask What time is it?", session_id: "test" },
             as: :json
      }.to have_enqueued_job(ClaudeAssistantJob)

      expect(response).to have_http_status(:ok)
    end

    it "rejects empty text" do
      post "/api/command", params: { text: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/transcription" do
    it "queues audio for transcription" do
      audio = Base64.strict_encode64("\x00" * 1000)
      expect {
        post "/api/transcription", params: { audio: audio, session_id: "test" }, as: :json
      }.to have_enqueued_job(SttJob)

      expect(response).to have_http_status(:ok)
    end
  end
end
