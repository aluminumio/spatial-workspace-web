import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { CommandParser } from "lib/command_parser"

export default class extends Controller {
  static targets = [
    "clock", "micButton", "micDot", "micLabel", "modeButton",
    "leftPanel", "centerPanel", "centerTitle", "centerContent",
    "rightPanel", "assistantOutput", "helpOverlay", "textInput",
    "emailList"
  ]

  connect() {
    this.consumer = createConsumer()
    this.pushToTalk = true
    this.micActive = false
    this.audioCapture = null
    this.commandParser = new CommandParser()
    this.sessionId = crypto.randomUUID()

    this.setupCable()
    this.setupKeyboard()
    this.startClock()
    this.initAudio()
  }

  disconnect() {
    this.consumer?.disconnect()
    this.audioCapture?.stop()
    clearInterval(this.clockInterval)
  }

  // --- ActionCable ---

  setupCable() {
    this.audioSubscription = this.consumer.subscriptions.create(
      { channel: "AudioChannel" },
      {
        connected: () => console.log("[cable] AudioChannel connected"),
        disconnected: () => {
          console.log("[cable] AudioChannel disconnected, reconnecting...")
          setTimeout(() => this.setupCable(), 2000)
        }
      }
    )

    this.transcriptionSubscription = this.consumer.subscriptions.create(
      { channel: "TranscriptionChannel" },
      {
        connected: () => console.log("[cable] TranscriptionChannel connected"),
        disconnected: () => console.log("[cable] TranscriptionChannel disconnected"),
        received: (data) => this.handleTranscription(data)
      }
    )
  }

  handleTranscription(data) {
    switch (data.type) {
      case "transcription":
        this.appendTranscription(data.text)
        const cmd = this.commandParser.parse(data.text)
        if (cmd) this.executeCommand(cmd)
        break
      case "assistant_delta":
        this.appendAssistantDelta(data.text)
        break
      case "assistant_done":
        this.finalizeAssistant()
        break
      case "tool_call":
        this.handleToolCall(data.tool, data.input)
        break
    }
  }

  // --- Audio ---

  async initAudio() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          channelCount: 1,
          sampleRate: 16000
        }
      })
      this.mediaStream = stream

      const audioCtx = new AudioContext({ sampleRate: 16000 })
      const source = audioCtx.createMediaStreamSource(stream)

      // Use ScriptProcessorNode for broad compatibility
      const processor = audioCtx.createScriptProcessor(4096, 1, 1)
      processor.onaudioprocess = (e) => {
        if (!this.micActive) return

        const float32 = e.inputBuffer.getChannelData(0)
        const int16 = new Int16Array(float32.length)
        for (let i = 0; i < float32.length; i++) {
          const s = Math.max(-1, Math.min(1, float32[i]))
          int16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
        }

        // Send as base64 since ActionCable doesn't support raw binary
        const base64 = btoa(String.fromCharCode(...new Uint8Array(int16.buffer)))
        this.audioSubscription?.send({ audio: base64 })
      }

      source.connect(processor)
      processor.connect(audioCtx.destination)
      this.audioContext = audioCtx

      // Suspend until mic is activated
      audioCtx.suspend()
    } catch (err) {
      console.error("Mic init failed:", err)
      this.appendAssistantMessage("Microphone access denied. Use text input instead.")
    }
  }

  toggleMic() {
    if (this.pushToTalk) {
      // In push-to-talk, toggle switches to continuous
      this.pushToTalk = false
      this.updateModeButton()
    }
    this.setMicActive(!this.micActive)
  }

  toggleMode() {
    this.pushToTalk = !this.pushToTalk
    this.updateModeButton()
    if (this.pushToTalk && this.micActive) {
      this.setMicActive(false)
    }
  }

  setMicActive(active) {
    this.micActive = active
    if (this.micDotTarget) {
      this.micDotTarget.className = active
        ? "w-2.5 h-2.5 rounded-full bg-spatial-green mic-active"
        : "w-2.5 h-2.5 rounded-full bg-spatial-muted"
    }
    if (this.micLabelTarget) {
      this.micLabelTarget.textContent = active ? "MIC ON" : "MIC OFF"
      this.micLabelTarget.className = active ? "text-sm text-spatial-green" : "text-sm text-spatial-muted"
    }

    if (active) {
      this.audioContext?.resume()
    } else {
      this.audioContext?.suspend()
    }
  }

  updateModeButton() {
    if (this.modeButtonTarget) {
      this.modeButtonTarget.textContent = this.pushToTalk ? "PUSH-TO-TALK" : "CONTINUOUS"
    }
  }

  // --- Keyboard ---

  setupKeyboard() {
    document.addEventListener("keydown", (e) => {
      // Don't capture when typing in input
      const inInput = e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA"

      if (e.code === "Space" && this.pushToTalk && !inInput) {
        e.preventDefault()
        if (!this.micActive) this.setMicActive(true)
      }

      if (e.key === "?" && !inInput) {
        e.preventDefault()
        this.toggleHelp()
      }

      if (e.key === "/" && !inInput) {
        e.preventDefault()
        this.textInputTarget?.focus()
      }

      if (e.key === "m" && !inInput) {
        e.preventDefault()
        this.toggleMode()
      }

      if (e.ctrlKey && e.key === "l") {
        e.preventDefault()
        this.clearAssistant()
      }

      if (e.key === "Escape") {
        if (!this.helpOverlayTarget.classList.contains("hidden")) {
          this.toggleHelp()
        }
      }
    })

    document.addEventListener("keyup", (e) => {
      if (e.code === "Space" && this.pushToTalk) {
        this.setMicActive(false)
      }
    })
  }

  // --- UI Actions ---

  sendText(e) {
    e.preventDefault()
    const text = this.textInputTarget.value.trim()
    if (!text) return

    this.textInputTarget.value = ""
    this.appendTranscription(text)

    const cmd = this.commandParser.parse(text)
    if (cmd) {
      this.executeCommand(cmd)
    } else {
      // Send directly to Claude
      this.sendToAssistant(text)
    }
  }

  async sendToAssistant(text) {
    this.appendAssistantMessage("...", "thinking")

    try {
      const response = await fetch("/api/command", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ text, session_id: this.sessionId })
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      // Response comes back via ActionCable
    } catch (err) {
      this.removeThinking()
      this.appendAssistantMessage(`Error: ${err.message}`)
    }
  }

  executeCommand(cmd) {
    switch (cmd.command) {
      case "ask":
        this.sendToAssistant(cmd.args)
        break
      case "email":
        this.sendToAssistant(`Check my email: ${cmd.args || "show inbox"}`)
        break
      case "read":
        this.sendToAssistant(`Read email: ${cmd.args || "latest"}`)
        break
      case "send":
        this.sendToAssistant(`Send email: ${cmd.args}`)
        break
      default:
        this.sendToAssistant(`${cmd.command}: ${cmd.args}`)
    }
  }

  // --- Transcription Display ---

  appendTranscription(text) {
    const output = this.centerContentTarget.querySelector("[data-transcription-display-target='output']")
    if (!output) return

    const el = document.createElement("div")
    el.className = "transcript-line flex gap-3 text-ar"
    el.innerHTML = `
      <span class="text-spatial-green shrink-0 text-sm mt-1">&gt;</span>
      <span class="text-spatial-text">${this.escapeHtml(text)}</span>
    `
    output.appendChild(el)
    this.scrollToBottom(output.parentElement)
  }

  appendAssistantDelta(text) {
    this.removeThinking()
    const output = this.assistantOutputTarget
    let current = output.querySelector(".assistant-streaming")
    if (!current) {
      current = document.createElement("div")
      current.className = "assistant-streaming text-ar text-spatial-text mb-3"
      output.appendChild(current)
    }
    current.textContent += text
    this.scrollToBottom(output)
  }

  finalizeAssistant() {
    const streaming = this.assistantOutputTarget.querySelector(".assistant-streaming")
    if (streaming) {
      streaming.classList.remove("assistant-streaming")
      streaming.classList.add("mb-4", "pb-4", "border-b", "border-spatial-border")
    }
  }

  appendAssistantMessage(text, className = "") {
    const el = document.createElement("div")
    el.className = `text-ar text-spatial-text mb-3 ${className}`
    el.textContent = text
    this.assistantOutputTarget.appendChild(el)
    this.scrollToBottom(this.assistantOutputTarget)
  }

  removeThinking() {
    this.assistantOutputTarget.querySelector(".thinking")?.remove()
  }

  handleToolCall(tool, input) {
    const el = document.createElement("div")
    el.className = "text-sm text-spatial-green mb-3 p-3 bg-spatial-panel rounded border border-spatial-border"
    el.innerHTML = `<span class="font-bold">[${this.escapeHtml(tool)}]</span> ${this.escapeHtml(JSON.stringify(input))}`
    this.assistantOutputTarget.appendChild(el)
    this.scrollToBottom(this.assistantOutputTarget)
  }

  clearAssistant() {
    this.assistantOutputTarget.innerHTML = '<p class="text-spatial-muted text-sm">Cleared. Ready.</p>'
  }

  toggleHelp() {
    this.helpOverlayTarget.classList.toggle("hidden")
  }

  // --- Utilities ---

  startClock() {
    const update = () => {
      if (this.clockTarget) {
        this.clockTarget.textContent = new Date().toLocaleTimeString("en-US", {
          hour: "2-digit", minute: "2-digit", hour12: false
        })
      }
    }
    update()
    this.clockInterval = setInterval(update, 1000)
  }

  scrollToBottom(el) {
    if (el) el.scrollTop = el.scrollHeight
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
