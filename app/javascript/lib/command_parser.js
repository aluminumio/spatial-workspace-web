export class CommandParser {
  constructor() {
    this.commands = new Map([
      ["email",  { aliases: ["mail", "inbox", "e-mail"], description: "Check or compose email" }],
      ["read",   { aliases: ["check", "reed"],           description: "Read inbox messages" }],
      ["send",   { aliases: ["reply", "sent"],           description: "Send a composed email" }],
      ["ask",    { aliases: ["question", "q", "asked"],  description: "Ask the assistant" }],
      ["open",   { aliases: ["browse", "go"],            description: "Open a URL" }],
      ["clear",  { aliases: ["reset", "clean"],          description: "Clear the workspace" }],
      ["help",   { aliases: ["?", "commands"],           description: "Show available commands" }],
    ])
  }

  parse(text) {
    // Strip punctuation and normalize whitespace for STT output
    const cleaned = text
      .replace(/[.,!?;:'"]/g, "")
      .replace(/\s+/g, " ")
      .trim()

    // 1. Exact /command at start
    let match = cleaned.match(/^\/(\w+)\s*(.*)?$/i)

    // 2. "slash <command>" anywhere in the text
    if (!match) {
      match = cleaned.match(/(?:^|\s)(?:slash|command)\s+(\w+)\s*(.*)?$/i)
    }

    // 3. "slash-command" or "slash.command" (STT sometimes joins or punctuates)
    if (!match) {
      match = cleaned.match(/(?:^|\s)slash[\s\-]+(\w+)\s*(.*)?$/i)
    }

    if (!match) return null

    const rawCommand = match[1].toLowerCase()
    const args = (match[2] || "").trim()

    const command = this.resolveAlias(rawCommand)
    if (!command) return null

    return { command, args, raw: text }
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
