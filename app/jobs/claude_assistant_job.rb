class ClaudeAssistantJob < ApplicationJob
  queue_as :default

  def perform(session_id, text)
    assistant = ClaudeAssistant.for_session(session_id)

    assistant.chat(text) do |event|
      case event[:type]
      when :text
        TranscriptionChannel.broadcast_to(
          session_id,
          { type: "assistant_delta", text: event[:text], timestamp: Time.current.iso8601 }
        )
      when :tool_call
        TranscriptionChannel.broadcast_to(
          session_id,
          { type: "tool_call", tool: event[:tool], input: event[:input], timestamp: Time.current.iso8601 }
        )
      end
    end

    TranscriptionChannel.broadcast_to(
      session_id,
      { type: "assistant_done", timestamp: Time.current.iso8601 }
    )
  end
end
