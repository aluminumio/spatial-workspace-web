class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token

  def command
    text = params[:text]
    session_id = params[:session_id] || session.id.to_s

    return render json: { error: "text required" }, status: :unprocessable_entity if text.blank?

    ClaudeAssistantJob.perform_later(session_id, text)
    render json: { status: "queued", session_id: session_id }
  end

  def transcription
    session_id = params[:session_id] || session.id.to_s
    audio = params[:audio]

    return render json: { error: "audio required" }, status: :unprocessable_entity if audio.blank?

    SttJob.perform_later(session_id, audio)
    render json: { status: "queued", session_id: session_id }
  end
end
