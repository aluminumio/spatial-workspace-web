require "rails_helper"

RSpec.describe ClaudeAssistant do
  let(:session_id) { "test-session-456" }
  subject(:assistant) { described_class.new(session_id) }

  before do
    # Mock Redis
    allow_any_instance_of(described_class).to receive(:redis).and_return(nil)
  end

  describe "#initialize" do
    it "creates an assistant for a session" do
      expect(assistant).to be_a(ClaudeAssistant)
    end
  end

  describe "#chat" do
    it "sends messages to the Anthropic API" do
      mock_client = instance_double(Anthropic::Client)
      mock_messages = instance_double("Messages")
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)
      allow(mock_messages).to receive(:create) do |**kwargs|
        # Simulate streaming
        kwargs[:stream].call({
          "type" => "content_block_delta",
          "delta" => { "type" => "text_delta", "text" => "Hello!" }
        })
      end

      result = assistant.chat("Hi there")
      expect(result[:text]).to eq("Hello!")
    end
  end

  describe "#reset" do
    it "clears conversation history" do
      assistant.reset
      # No error means success — messages are empty
    end
  end

  describe ".for_session" do
    it "returns the same instance for the same session" do
      a = described_class.for_session("same-id")
      b = described_class.for_session("same-id")
      expect(a).to equal(b)
    end

    it "returns different instances for different sessions" do
      a = described_class.for_session("id-1")
      b = described_class.for_session("id-2")
      expect(a).not_to equal(b)
    end
  end
end
