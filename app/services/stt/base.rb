module Stt
  class Base
    def transcribe(audio_bytes, format: "pcm", sample_rate: 16_000)
      raise NotImplementedError, "#{self.class}#transcribe must be implemented"
    end

    def self.for(provider = nil)
      provider ||= SPATIAL_CONFIG[:stt_provider]

      case provider.to_s
      when "whisper_api"    then Stt::WhisperApi.new
      when "whisper_local"  then Stt::WhisperLocal.new
      when "deepgram"       then Stt::Deepgram.new
      else raise ArgumentError, "Unknown STT provider: #{provider}"
      end
    end

    private

    def pcm_to_wav(pcm_bytes, sample_rate: 16_000, channels: 1, bits_per_sample: 16)
      data_size = pcm_bytes.bytesize
      byte_rate = sample_rate * channels * bits_per_sample / 8
      block_align = channels * bits_per_sample / 8

      header = [
        "RIFF",
        data_size + 36,
        "WAVE",
        "fmt ",
        16,
        1,
        channels,
        sample_rate,
        byte_rate,
        block_align,
        bits_per_sample,
        "data",
        data_size
      ].pack("A4VA4A4VvvVVvvA4V")

      header + pcm_bytes
    end
  end
end
