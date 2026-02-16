require "rails_helper"

RSpec.describe AudioChannel, type: :channel do
  let(:session_id) { "test-session-123" }

  before do
    stub_connection session_id: session_id
  end

  describe "#subscribed" do
    it "subscribes successfully" do
      subscribe
      expect(subscription).to be_confirmed
    end

    it "streams for the session" do
      subscribe
      expect(subscription).to have_stream_for(session_id)
    end
  end

  describe "#receive" do
    before { subscribe }

    it "buffers incoming audio data" do
      # 16-bit PCM, 16kHz, 1 second = 32000 bytes
      audio = Base64.strict_encode64("\x00" * 32_000)
      expect {
        perform(:receive, { "audio" => audio })
      }.not_to have_enqueued_job(SttJob)
    end

    it "flushes buffer when chunk threshold reached" do
      # Default 3 seconds = 96000 bytes
      audio = Base64.strict_encode64("\x00" * 96_000)
      expect {
        perform(:receive, { "audio" => audio })
      }.to have_enqueued_job(SttJob).with(session_id, anything)
    end
  end

  describe "#unsubscribed" do
    it "flushes remaining buffer on disconnect" do
      subscribe
      audio = Base64.strict_encode64("\x00" * 16_000)
      perform(:receive, { "audio" => audio })

      expect {
        subscription.unsubscribe_from_channel
      }.to have_enqueued_job(SttJob)
    end
  end
end
