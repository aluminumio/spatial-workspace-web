# Spatial Workspace Web

Rails 8 server for Spatial Workspace — voice-to-text pipeline, AI assistant, and AR-optimized workspace UI.

Designed for auto-deploy to Heroku, Render, Railway, or any PaaS that detects a Ruby buildpack.

## Deploy

Set these ENV vars on your PaaS:

```
SECRET_KEY_BASE=<ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'>
REDIS_URL=<from your Redis addon>
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-proj-...
```

That's it. Push to `main` and auto-deploy handles the rest.

## Local Development

```bash
cp .env.example .env  # fill in API keys
bundle install
bin/rails server -b 0.0.0.0
```

Requires Redis running locally for ActionCable.

## Architecture

```
Browser/WebView → getUserMedia (mic)
  → WebSocket PCM frames → ActionCable AudioChannel
  → SttJob (Whisper API / Deepgram / local Whisper)
  → TranscriptionChannel broadcasts text back
  → ClaudeAssistantJob streams AI responses
  → Three-panel workspace UI (Stimulus + Tailwind)
```

## Testing

```bash
bundle exec rspec

# Test audio pipeline with a WAV file
ruby script/test_audio.rb path/to/audio.wav
```

## Companion App

Android thin client: [spatial-workspace-android](https://github.com/aluminumio/spatial-workspace-android)
