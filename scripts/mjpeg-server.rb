#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'
require 'fcntl'

# Simple MJPEG HTTP server for rpicam-vid streaming
# Reads MJPEG frames from rpicam-vid stdout and serves to multiple clients
class MjpegServer
  BOUNDARY = 'FRAME'
  PORT = 8081

  def initialize
    @clients = []
    @mutex = Mutex.new
    @server = TCPServer.new('0.0.0.0', PORT)
    $stdout.sync = true
    $stderr.sync = true
    puts "MJPEG Server starting on port #{PORT}..."
  end

  def start(stream_source = $stdin)
    # Start thread to accept client connections
    Thread.new { accept_clients }

    # Read MJPEG stream from rpicam-vid and broadcast to all clients
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
    # Read and discard the HTTP request headers
    loop do
      line = client.gets
      break if line.nil? || line.strip.empty?
    end

    # Send HTTP headers for multipart MJPEG stream
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Type: multipart/x-mixed-replace; boundary=#{BOUNDARY}\r\n")
    client.write("Connection: close\r\n")
    client.write("\r\n")
    client.flush

    @mutex.synchronize { @clients << client }
    puts "Client connected (#{@clients.size} total)"

    # Keep connection alive - client thread will be terminated when write fails or socket closes
    # HTTP clients don't send data after initial request, they only receive
    sleep
  rescue StandardError => e
    puts "Client error: #{e.message}"
  ensure
    @mutex.synchronize { @clients.delete(client) }
    client.close unless client.closed?
    puts "Client disconnected (#{@clients.size} remaining)"
  end

  def read_and_broadcast_stream(stream_source)
    buffer = String.new(encoding: 'ASCII-8BIT')
    frame_start = "\xff\xd8".b # JPEG SOI marker
    frame_end = "\xff\xd9".b   # JPEG EOI marker
    frame_count = 0
    retry_count = 0

    puts "Starting to read MJPEG stream..."
    puts "Syncing to first JPEG frame..."

    # Sync to first frame start marker
    sync_buffer = String.new(encoding: 'ASCII-8BIT')
    until sync_buffer.include?(frame_start)
      data = stream_source.read(4096)
      break unless data
      data.force_encoding('ASCII-8BIT')
      sync_buffer << data
      sync_buffer = sync_buffer[-8192..] || sync_buffer if sync_buffer.size > 16384
    end

    # Start buffer from first frame marker
    if (start_pos = sync_buffer.index(frame_start))
      buffer << sync_buffer[start_pos..-1]
      puts "Synced! Found first frame marker, starting processing..."
    else
      puts "ERROR: Could not sync to JPEG stream"
      return
    end

    loop do
      data = stream_source.read(4096)
      unless data
        # EOF can occur if writer hasn't connected yet (FIFO behavior)
        retry_count += 1
        if retry_count < 10
          puts "Waiting for data... (attempt #{retry_count})"
          sleep 0.5
          next
        end
        puts "No more data from stream, exiting..."
        break
      end

      retry_count = 0  # Reset on successful read

      data.force_encoding('ASCII-8BIT')
      buffer << data

      # Extract complete JPEG frames
      while (start_idx = buffer.index(frame_start))
        end_idx = buffer.index(frame_end, start_idx + 2)
        unless end_idx
          # Check if we have enough data - JPEG frames can be large
          if buffer.size > 200_000
            puts "ERROR: Buffer size #{buffer.size}, frame start at #{start_idx}, still no end marker"
            buffer.clear
            break
          end
          break  # Wait for more data
        end

        # Extract frame (including EOI marker)
        frame = buffer.slice!(0, end_idx + 2)
        if frame.size < 100
          puts "Skipping invalid frame (size: #{frame.size})"
          next
        end

        frame_count += 1
        puts "Broadcasting frame ##{frame_count} (#{frame.size} bytes)" if (frame_count % 100) == 0

        broadcast_frame(frame)
      end

      # Keep last incomplete frame in buffer (allow up to 100KB for high-quality JPEG frames)
      buffer = buffer[-50_000..] || String.new if buffer.size > 100_000
    end
  end

  def broadcast_frame(frame)
    @mutex.synchronize do
      @clients.each do |client|
        begin
          client.write("--#{BOUNDARY}\r\n")
          client.write("Content-Type: image/jpeg\r\n")
          client.write("Content-Length: #{frame.bytesize}\r\n")
          client.write("\r\n")
          client.write(frame)
          client.write("\r\n")
          client.flush
        rescue StandardError => e
          puts "Error broadcasting to client: #{e.message}"
          @clients.delete(client)
        end
      end
    end
  rescue StandardError => e
    puts "Broadcast error: #{e.message}"
  end
end

# Run server
server = MjpegServer.new
if ARGV[0]
  puts "Opening FIFO: #{ARGV[0]}"
  # Open in normal blocking mode - rpicam-vid should already have it open for writing
  stream_source = File.open(ARGV[0], 'rb')
  puts "FIFO opened successfully"
else
  stream_source = $stdin
  puts "Reading from stdin"
end
server.start(stream_source)
