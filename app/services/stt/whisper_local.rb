module Stt
  class WhisperLocal < Base
    def transcribe(audio_bytes, format: "pcm", sample_rate: 16_000)
      wav_data = format == "pcm" ? pcm_to_wav(audio_bytes, sample_rate: sample_rate) : audio_bytes

      endpoint = SPATIAL_CONFIG[:stt_endpoint] || "http://localhost:9000/asr"

      temp_file = Tempfile.new(["audio", ".wav"])
      temp_file.binmode
      temp_file.write(wav_data)
      temp_file.rewind

      begin
        uri = URI(endpoint)
        request = Net::HTTP::Post.new(uri)

        form_data = [
          ["audio_file", temp_file, { filename: "audio.wav", content_type: "audio/wav" }]
        ]

        request.set_form(form_data, "multipart/form-data")

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        if response.code.to_i == 200
          parsed = JSON.parse(response.body)
          parsed["text"] || parsed.to_s
        else
          Rails.logger.error("Whisper local STT failed: #{response.code} #{response.body}")
          ""
        end
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end
