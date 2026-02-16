require "rails_helper"

RSpec.describe NoiseGate do
  describe ".process" do
    it "silences audio below threshold" do
      # Create quiet audio (near silence)
      quiet_samples = Array.new(1600) { rand(-10..10) }
      pcm = quiet_samples.pack("s<*")

      result = described_class.process(pcm)
      output_samples = result.unpack("s<*")

      # Most samples should be zeroed out
      non_zero = output_samples.count { |s| s != 0 }
      expect(non_zero).to be < output_samples.length / 2
    end

    it "passes through audio above threshold" do
      # Create loud audio
      loud_samples = Array.new(1600) { rand(-20000..20000) }
      pcm = loud_samples.pack("s<*")

      result = described_class.process(pcm)
      output_samples = result.unpack("s<*")

      non_zero = output_samples.count { |s| s != 0 }
      expect(non_zero).to be > output_samples.length / 2
    end

    it "returns empty bytes for empty input" do
      result = described_class.process("")
      expect(result).to eq("")
    end
  end
end
