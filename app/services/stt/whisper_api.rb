module Stt
  class WhisperApi < Base
    def transcribe(audio_bytes, format: "pcm", sample_rate: 16_000)
      wav_data = format == "pcm" ? pcm_to_wav(audio_bytes, sample_rate: sample_rate) : audio_bytes

      client = OpenAI::Client.new(access_token: SPATIAL_CONFIG[:stt_api_key])

      temp_file = Tempfile.new(["audio", ".wav"])
      temp_file.binmode
      temp_file.write(wav_data)
      temp_file.rewind

      begin
        response = client.audio.transcribe(
          parameters: {
            file: temp_file,
            model: SPATIAL_CONFIG[:whisper_model] || "whisper-1",
            language: "en",
            response_format: "json"
          }
        )

        response.dig("text") || ""
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end
