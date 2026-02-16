class SttJob < ApplicationJob
  queue_as :default

  def perform(session_id, base64_audio)
    audio_bytes = Base64.strict_decode64(base64_audio)

    provider = Stt::Base.for
    text = provider.transcribe(audio_bytes)

    return if text.blank?

    TranscriptionChannel.broadcast_to(
      session_id,
      { type: "transcription", text: text, timestamp: Time.current.iso8601 }
    )

    # Check for slash commands and auto-dispatch to Claude
    if text.strip.start_with?("/")
      ClaudeAssistantJob.perform_later(session_id, text.strip)
    end
  end
end
