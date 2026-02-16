require "concurrent"

class ClaudeAssistant
  SESSIONS = Concurrent::Map.new

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a spatial workspace assistant running on AR glasses (Rokid Max 2).
    You help the user with:
    - Email triage and composition
    - Dictation and document editing
    - Command execution and system control
    - Information lookup and summarization

    Keep responses concise — the user is viewing on a heads-up display.
    Use short paragraphs and bullet points. Avoid long prose.

    When composing emails, return them as structured tool calls.
    When the user gives a slash command, execute the appropriate tool.
  PROMPT

  TOOLS = [
    {
      name: "compose_email",
      description: "Compose an email draft",
      input_schema: {
        type: "object",
        properties: {
          to: { type: "string", description: "Recipient email address" },
          subject: { type: "string", description: "Email subject line" },
          body: { type: "string", description: "Email body text" }
        },
        required: ["to", "subject", "body"]
      }
    },
    {
      name: "read_email",
      description: "Read emails from inbox. Returns a list of recent emails.",
      input_schema: {
        type: "object",
        properties: {
          folder: { type: "string", description: "Mailbox folder", default: "inbox" },
          count: { type: "integer", description: "Number of emails to fetch", default: 10 }
        }
      }
    },
    {
      name: "open_url",
      description: "Open a URL in the workspace browser panel",
      input_schema: {
        type: "object",
        properties: {
          url: { type: "string", description: "URL to open" }
        },
        required: ["url"]
      }
    }
  ].freeze

  def initialize(session_id)
    @session_id = session_id
    @messages = load_messages
  end

  def chat(user_text, &on_stream)
    @messages << { role: "user", content: user_text }

    client = Anthropic::Client.new(api_key: SPATIAL_CONFIG[:claude_api_key])

    full_response = ""
    tool_use_blocks = []

    client.messages.create(
      model: SPATIAL_CONFIG[:claude_model],
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages: @messages,
      tools: TOOLS,
      stream: proc { |event|
        case event["type"]
        when "content_block_delta"
          delta = event.dig("delta")
          if delta && delta["type"] == "text_delta"
            text = delta["text"]
            full_response << text
            on_stream&.call(type: :text, text: text)
          end
        when "content_block_stop"
          # block completed
        when "message_delta"
          if event.dig("delta", "stop_reason") == "tool_use"
            # will handle tool results
          end
        end
      }
    )

    @messages << { role: "assistant", content: full_response }
    save_messages

    { text: full_response, tool_calls: tool_use_blocks }
  end

  def reset
    @messages = []
    save_messages
  end

  private

  def load_messages
    stored = redis&.get(redis_key)
    stored ? JSON.parse(stored, symbolize_names: false).map(&:with_indifferent_access) : []
  rescue
    []
  end

  def save_messages
    # Keep last 50 messages to avoid unbounded growth
    @messages = @messages.last(50)
    redis&.set(redis_key, @messages.to_json, ex: 86_400)
  rescue => e
    Rails.logger.warn("Failed to persist conversation: #{e.message}")
  end

  def redis_key
    "spatial:conversation:#{@session_id}"
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  rescue
    nil
  end

  def self.for_session(session_id)
    SESSIONS.compute_if_absent(session_id) { new(session_id) }
  end
end
