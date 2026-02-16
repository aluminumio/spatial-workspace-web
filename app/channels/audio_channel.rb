class AudioChannel < ApplicationCable::Channel
  SAMPLE_RATE = 16_000
  BYTES_PER_SAMPLE = 2

  def subscribed
    @buffer = StringIO.new
    @buffer.set_encoding(Encoding::BINARY)
    @chunk_bytes = SPATIAL_CONFIG[:audio_chunk_seconds].to_i * SAMPLE_RATE * BYTES_PER_SAMPLE

    stream_for session_id
  end

  def unsubscribed
    flush_buffer if @buffer && @buffer.size > 0
  end

  def receive(data)
    audio_data = if data.is_a?(Hash) && data["audio"]
      Base64.decode64(data["audio"])
    elsif data.is_a?(String)
      data.force_encoding(Encoding::BINARY)
    else
      return
    end

    @buffer.write(audio_data)

    if @buffer.size >= @chunk_bytes
      flush_buffer
    end
  end

  private

  def flush_buffer
    return if @buffer.size == 0

    audio_bytes = @buffer.string.dup
    @buffer.truncate(0)
    @buffer.rewind

    if noise_suppression_server?
      audio_bytes = NoiseGate.process(audio_bytes, SAMPLE_RATE)
    end

    SttJob.perform_later(session_id, Base64.strict_encode64(audio_bytes))
  end

  def noise_suppression_server?
    %w[server both].include?(SPATIAL_CONFIG[:noise_suppression])
  end
end
