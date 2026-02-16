class TranscriptionChannel < ApplicationCable::Channel
  def subscribed
    stream_for session_id
  end

  def unsubscribed
    # cleanup if needed
  end

  def send_command(data)
    text = data["text"]
    return unless text.present?

    ClaudeAssistantJob.perform_later(session_id, text)
  end
end
