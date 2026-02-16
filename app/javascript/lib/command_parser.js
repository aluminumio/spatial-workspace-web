export class CommandParser {
  constructor() {
    this.commands = new Map([
      ["email",  { aliases: ["mail", "inbox"], description: "Check or compose email" }],
      ["read",   { aliases: ["check"],         description: "Read inbox messages" }],
      ["send",   { aliases: ["reply"],         description: "Send a composed email" }],
      ["ask",    { aliases: ["question", "q"], description: "Ask the assistant" }],
      ["open",   { aliases: ["browse", "go"],  description: "Open a URL" }],
      ["clear",  { aliases: ["reset"],         description: "Clear the workspace" }],
      ["help",   { aliases: ["?", "commands"], description: "Show available commands" }],
    ])
  }

  parse(text) {
    const trimmed = text.trim()

    // Match /command or "slash command" spoken aloud
    let match = trimmed.match(/^\/(\w+)\s*(.*)?$/i)

    if (!match) {
      // Try matching spoken "slash email" or "command email"
      match = trimmed.match(/^(?:slash|command)\s+(\w+)\s*(.*)?$/i)
    }

    if (!match) return null

    const rawCommand = match[1].toLowerCase()
    const args = (match[2] || "").trim()

    // Resolve aliases
    const command = this.resolveAlias(rawCommand)
    if (!command) return null

    return { command, args, raw: trimmed }
  }

  resolveAlias(name) {
    if (this.commands.has(name)) return name

    for (const [cmd, config] of this.commands) {
      if (config.aliases.includes(name)) return cmd
    }

    return null
  }

  getCommands() {
    return Array.from(this.commands.entries()).map(([name, config]) => ({
      name,
      ...config
    }))
  }

  isCommand(text) {
    return this.parse(text) !== null
  }
}
