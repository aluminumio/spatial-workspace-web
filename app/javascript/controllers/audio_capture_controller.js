import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.active = false
    this.stream = null
    this.audioContext = null
    this.processor = null
  }

  disconnect() {
    this.stop()
  }

  async start() {
    if (this.active) return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          channelCount: 1,
          sampleRate: { ideal: 16000 }
        }
      })

      this.audioContext = new AudioContext({ sampleRate: 16000 })
      const source = this.audioContext.createMediaStreamSource(this.stream)

      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1)
      this.processor.onaudioprocess = (e) => this.processAudio(e)

      source.connect(this.processor)
      this.processor.connect(this.audioContext.destination)

      this.active = true
      this.dispatch("started")
    } catch (err) {
      console.error("Audio capture failed:", err)
      this.dispatch("error", { detail: err.message })
    }
  }

  stop() {
    this.active = false
    this.processor?.disconnect()
    this.audioContext?.close()
    this.stream?.getTracks().forEach(t => t.stop())
    this.processor = null
    this.audioContext = null
    this.stream = null
    this.dispatch("stopped")
  }

  processAudio(e) {
    if (!this.active) return

    const float32 = e.inputBuffer.getChannelData(0)
    const pcm16 = this.float32ToInt16(float32)

    this.dispatch("audio", {
      detail: { buffer: pcm16.buffer, samples: pcm16.length }
    })
  }

  float32ToInt16(float32) {
    const int16 = new Int16Array(float32.length)
    for (let i = 0; i < float32.length; i++) {
      const s = Math.max(-1, Math.min(1, float32[i]))
      int16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
    }
    return int16
  }
}
