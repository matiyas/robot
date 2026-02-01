#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'
require 'fcntl'

# Simple MJPEG HTTP server for rpicam-vid streaming
# Reads MJPEG frames from rpicam-vid stdout and serves to multiple clients
class MjpegServer
  BOUNDARY = 'FRAME'
  PORT = 8081
  FRAME_START = "\xff\xd8".b # JPEG SOI marker
  FRAME_END = "\xff\xd9".b   # JPEG EOI marker
  MIN_FRAME_SIZE = 100
  MAX_BUFFER_SIZE = 100_000
  BUFFER_TRIM_SIZE = 50_000
  MAX_ERROR_BUFFER = 200_000

  def initialize
    @clients = []
    @mutex = Mutex.new
    @server = TCPServer.new('0.0.0.0', PORT)
    $stdout.sync = true
    $stderr.sync = true
    puts "MJPEG Server starting on port #{PORT}..."
  end

  def start(stream_source = $stdin)
    Thread.new { accept_clients }
    read_and_broadcast_stream(stream_source)
  end

  private

  def accept_clients
    loop do
      client = @server.accept
      Thread.new { handle_client(client) }
    end
  end

  def handle_client(client)
    discard_http_request(client)
    send_http_headers(client)
    register_client(client)
    sleep # Keep alive until write fails
  rescue StandardError => e
    puts "Client error: #{e.message}"
  ensure
    unregister_client(client)
  end

  def discard_http_request(client)
    loop do
      line = client.gets
      break if line.nil? || line.strip.empty?
    end
  end

  def send_http_headers(client)
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Type: multipart/x-mixed-replace; boundary=#{BOUNDARY}\r\n")
    client.write("Connection: close\r\n\r\n")
    client.flush
  end

  def register_client(client)
    @mutex.synchronize { @clients << client }
    puts "Client connected (#{@clients.size} total)"
  end

  def unregister_client(client)
    @mutex.synchronize { @clients.delete(client) }
    client.close unless client.closed?
    puts "Client disconnected (#{@clients.size} remaining)"
  end

  def read_and_broadcast_stream(stream_source)
    buffer = String.new(encoding: 'ASCII-8BIT')
    frame_count = 0

    sync_to_first_frame(stream_source, buffer)
    return unless buffer.size.positive?

    process_stream(stream_source, buffer, frame_count)
  end

  def sync_to_first_frame(stream_source, buffer)
    puts 'Starting to read MJPEG stream...'
    puts 'Syncing to first JPEG frame...'

    sync_buffer = String.new(encoding: 'ASCII-8BIT')
    sync_buffer = read_until_frame_marker(stream_source, sync_buffer)

    copy_synced_buffer_to_main(sync_buffer, buffer)
  end

  def read_until_frame_marker(stream_source, sync_buffer)
    until sync_buffer.include?(FRAME_START)
      data = stream_source.read(4096)
      break unless data

      data.force_encoding('ASCII-8BIT')
      sync_buffer << data
      sync_buffer = trim_sync_buffer(sync_buffer)
    end
    sync_buffer
  end

  def trim_sync_buffer(sync_buffer)
    sync_buffer.size > 16_384 ? (sync_buffer[-8192..] || sync_buffer) : sync_buffer
  end

  def copy_synced_buffer_to_main(sync_buffer, buffer)
    start_pos = sync_buffer.index(FRAME_START)
    if start_pos
      buffer << sync_buffer[start_pos..]
      puts 'Synced! Found first frame marker, starting processing...'
    else
      puts 'ERROR: Could not sync to JPEG stream'
    end
  end

  def process_stream(stream_source, buffer, frame_count)
    retry_count = 0

    loop do
      data = stream_source.read(4096)
      unless data
        retry_count += 1
        break if retry_count >= 10

        puts "Waiting for data... (attempt #{retry_count})"
        sleep 0.5
        next
      end

      retry_count = 0
      data.force_encoding('ASCII-8BIT')
      buffer << data

      frame_count = extract_and_broadcast_frames(buffer, frame_count)
      trim_buffer(buffer)
    end
  end

  def extract_and_broadcast_frames(buffer, frame_count)
    while (start_idx = buffer.index(FRAME_START))
      end_idx = buffer.index(FRAME_END, start_idx + 2)
      break unless end_idx || buffer_overflow?(buffer, start_idx)

      frame = buffer.slice!(0, end_idx + 2)
      frame_count = process_frame(frame, frame_count)
    end
    frame_count
  end

  def buffer_overflow?(buffer, start_idx)
    return false if buffer.size <= MAX_ERROR_BUFFER

    puts "ERROR: Buffer size #{buffer.size}, frame start at #{start_idx}, still no end marker"
    buffer.clear
    true
  end

  def process_frame(frame, frame_count)
    if frame.size < MIN_FRAME_SIZE
      puts "Skipping invalid frame (size: #{frame.size})"
      return frame_count
    end

    frame_count += 1
    puts "Broadcasting frame ##{frame_count} (#{frame.size} bytes)" if (frame_count % 100).zero?
    broadcast_frame(frame)
    frame_count
  end

  def trim_buffer(buffer)
    buffer.replace(buffer[-BUFFER_TRIM_SIZE..] || +'') if buffer.size > MAX_BUFFER_SIZE
  end

  def broadcast_frame(frame)
    @mutex.synchronize do
      @clients.each do |client|
        send_frame_to_client(client, frame)
      rescue StandardError => e
        puts "Error broadcasting to client: #{e.message}"
        @clients.delete(client)
      end
    end
  rescue StandardError => e
    puts "Broadcast error: #{e.message}"
  end

  def send_frame_to_client(client, frame)
    client.write("--#{BOUNDARY}\r\n")
    client.write("Content-Type: image/jpeg\r\n")
    client.write("Content-Length: #{frame.bytesize}\r\n\r\n")
    client.write(frame)
    client.write("\r\n")
    client.flush
  end
end

# Run server
server = MjpegServer.new
if ARGV[0]
  puts "Opening FIFO: #{ARGV[0]}"
  stream_source = File.open(ARGV[0], 'rb')
  puts 'FIFO opened successfully'
else
  stream_source = $stdin
  puts 'Reading from stdin'
end
server.start(stream_source)
