#!/usr/bin/env ruby
# frozen_string_literal: true

# Simulates sending a WAV file over WebSocket for testing without glasses.
#
# Usage:
#   ruby script/test_audio.rb [path/to/audio.wav] [server_url]
#
# Examples:
#   ruby script/test_audio.rb                          # sends silence
#   ruby script/test_audio.rb recording.wav             # sends a WAV file
#   ruby script/test_audio.rb recording.wav ws://localhost:3000/cable

require "net/http"
require "json"
require "base64"
require "uri"
require "websocket-client-simple"

SERVER_URL = ARGV[1] || "ws://localhost:3000/cable"
WAV_FILE = ARGV[0]
SESSION_ID = "test-audio-#{Time.now.to_i}"
CHUNK_SIZE = 96_000  # 3 seconds of 16kHz 16-bit mono

def generate_silence(duration_seconds = 5)
  sample_rate = 16_000
  num_samples = sample_rate * duration_seconds
  Array.new(num_samples, 0).pack("s<*")
end

def read_wav_pcm(path)
  data = File.binread(path)

  # Skip WAV header (44 bytes for standard PCM WAV)
  if data[0..3] == "RIFF" && data[8..11] == "WAVE"
    # Find the data chunk
    offset = 12
    while offset < data.length - 8
      chunk_id = data[offset..offset + 3]
      chunk_size = data[offset + 4..offset + 7].unpack1("V")
      if chunk_id == "data"
        return data[offset + 8, chunk_size]
      end
      offset += 8 + chunk_size
    end
  end

  # Fallback: assume raw PCM after 44-byte header
  data[44..]
end

def main
  pcm_data = if WAV_FILE && File.exist?(WAV_FILE)
    puts "Reading audio from: #{WAV_FILE}"
    read_wav_pcm(WAV_FILE)
  else
    puts "No WAV file specified, generating 5 seconds of silence..."
    generate_silence(5)
  end

  puts "PCM data: #{pcm_data.bytesize} bytes (#{pcm_data.bytesize / 32_000.0}s at 16kHz)"
  puts "Connecting to: #{SERVER_URL}"

  ws = WebSocket::Client::Simple.connect(SERVER_URL)

  connected = false

  ws.on :open do
    puts "Connected!"

    # Subscribe to AudioChannel
    subscribe_msg = {
      command: "subscribe",
      identifier: { channel: "AudioChannel" }.to_json
    }
    ws.send(subscribe_msg.to_json)
    puts "Subscribed to AudioChannel"

    # Also subscribe to TranscriptionChannel to see results
    subscribe_msg2 = {
      command: "subscribe",
      identifier: { channel: "TranscriptionChannel" }.to_json
    }
    ws.send(subscribe_msg2.to_json)
    puts "Subscribed to TranscriptionChannel"

    connected = true

    # Send audio in chunks
    sleep 1
    offset = 0
    chunk_num = 0

    while offset < pcm_data.bytesize
      chunk = pcm_data[offset, CHUNK_SIZE] || pcm_data[offset..]
      encoded = Base64.strict_encode64(chunk)

      message = {
        command: "message",
        identifier: { channel: "AudioChannel" }.to_json,
        data: { action: "receive", audio: encoded }.to_json
      }

      ws.send(message.to_json)
      chunk_num += 1
      puts "Sent chunk #{chunk_num}: #{chunk.bytesize} bytes"

      offset += CHUNK_SIZE
      sleep 0.1
    end

    puts "\nAll audio sent. Waiting for transcription..."
  end

  ws.on :message do |msg|
    data = JSON.parse(msg.data) rescue nil
    next unless data

    if data["type"] == "ping"
      # ignore pings
    elsif data["message"]
      message = data["message"]
      case message["type"]
      when "transcription"
        puts "\n=== TRANSCRIPTION ==="
        puts message["text"]
        puts "===================="
      when "assistant_delta"
        print message["text"]
      when "assistant_done"
        puts "\n--- Assistant done ---"
      when "tool_call"
        puts "\n[TOOL: #{message['tool']}] #{message['input']}"
      else
        puts "Received: #{message.inspect}"
      end
    elsif data["type"] == "confirm_subscription"
      puts "Subscription confirmed: #{data['identifier']}"
    end
  end

  ws.on :error do |e|
    puts "Error: #{e.message}"
  end

  ws.on :close do |e|
    puts "Connection closed: #{e}"
  end

  # Keep running for 30 seconds to receive transcription
  sleep 30
  ws.close
  puts "Done."
end

main
