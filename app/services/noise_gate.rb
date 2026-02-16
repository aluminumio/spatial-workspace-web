class NoiseGate
  THRESHOLD_DB = -40.0
  ATTACK_SAMPLES = 160   # 10ms at 16kHz
  RELEASE_SAMPLES = 800  # 50ms at 16kHz

  class << self
    def process(pcm_bytes, sample_rate = 16_000)
      samples = pcm_bytes.unpack("s<*")
      return pcm_bytes if samples.empty?

      threshold = db_to_linear(THRESHOLD_DB)
      gate_open = false
      release_counter = 0
      output = []

      samples.each do |sample|
        amplitude = sample.abs / 32768.0

        if amplitude > threshold
          gate_open = true
          release_counter = RELEASE_SAMPLES
        elsif release_counter > 0
          release_counter -= 1
        else
          gate_open = false
        end

        output << (gate_open ? sample : 0)
      end

      output.pack("s<*")
    end

    private

    def db_to_linear(db)
      10.0 ** (db / 20.0)
    end
  end
end
