import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "output"]

  connect() {
    this.maxLines = 100
  }

  addLine(text, type = "user") {
    const el = document.createElement("div")
    el.className = "transcript-line mb-2"

    const prefix = type === "user" ? ">" : "#"
    const color = type === "user" ? "text-spatial-green" : "text-spatial-text"

    el.innerHTML = `
      <div class="flex gap-2 text-ar">
        <span class="${color} shrink-0 font-bold">${prefix}</span>
        <span class="text-spatial-text">${this.escapeHtml(text)}</span>
      </div>
      <div class="text-xs text-spatial-muted mt-0.5 ml-5">
        ${new Date().toLocaleTimeString()}
      </div>
    `

    this.outputTarget.appendChild(el)
    this.pruneOldLines()
    this.scrollToBottom()
  }

  addInterim(text) {
    let interim = this.outputTarget.querySelector(".interim-text")
    if (!interim) {
      interim = document.createElement("div")
      interim.className = "interim-text text-ar text-spatial-muted italic ml-5"
      this.outputTarget.appendChild(interim)
    }
    interim.textContent = text
    this.scrollToBottom()
  }

  clearInterim() {
    this.outputTarget.querySelector(".interim-text")?.remove()
  }

  pruneOldLines() {
    const lines = this.outputTarget.querySelectorAll(".transcript-line")
    while (lines.length > this.maxLines) {
      lines[0].remove()
    }
  }

  scrollToBottom() {
    if (this.containerTarget) {
      this.containerTarget.scrollTop = this.containerTarget.scrollHeight
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
