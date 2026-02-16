module Stt
  class Deepgram < Base
    ENDPOINT = "https://api.deepgram.com/v1/listen".freeze

    def transcribe(audio_bytes, format: "pcm", sample_rate: 16_000)
      wav_data = format == "pcm" ? pcm_to_wav(audio_bytes, sample_rate: sample_rate) : audio_bytes
      api_key = SPATIAL_CONFIG[:stt_api_key]

      uri = URI("#{ENDPOINT}?model=nova-2&language=en&smart_format=true")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Token #{api_key}"
      request["Content-Type"] = "audio/wav"
      request.body = wav_data

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code.to_i == 200
        parsed = JSON.parse(response.body)
        parsed.dig("results", "channels", 0, "alternatives", 0, "transcript") || ""
      else
        Rails.logger.error("Deepgram STT failed: #{response.code} #{response.body}")
        ""
      end
    end
  end
end
