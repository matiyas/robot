#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'

# Simple MJPEG HTTP server for rpicam-vid streaming
# Reads MJPEG frames from rpicam-vid stdout and serves to multiple clients
class MjpegServer
  BOUNDARY = 'FRAME'
  PORT = 8081

  def initialize
    @clients = []
    @mutex = Mutex.new
    @server = TCPServer.new('0.0.0.0', PORT)
    puts "MJPEG Server starting on port #{PORT}..."
  end

  def start
    # Start thread to accept client connections
    Thread.new { accept_clients }

    # Read MJPEG stream from rpicam-vid and broadcast to all clients
    read_and_broadcast_stream
  end

  private

  def accept_clients
    loop do
      client = @server.accept
      Thread.new { handle_client(client) }
    end
  end

  def handle_client(client)
    # Send HTTP headers for multipart MJPEG stream
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Type: multipart/x-mixed-replace; boundary=#{BOUNDARY}\r\n")
    client.write("Connection: close\r\n")
    client.write("\r\n")

    @mutex.synchronize { @clients << client }
    puts "Client connected (#{@clients.size} total)"

    # Keep connection alive until client disconnects
    client.wait_readable
  rescue StandardError => e
    puts "Client error: #{e.message}"
  ensure
    @mutex.synchronize { @clients.delete(client) }
    client.close unless client.closed?
    puts "Client disconnected (#{@clients.size} remaining)"
  end

  def read_and_broadcast_stream
    buffer = String.new
    frame_start = "\xff\xd8".b # JPEG SOI marker
    frame_end = "\xff\xd9".b   # JPEG EOI marker

    loop do
      data = $stdin.read(4096)
      break unless data

      buffer << data

      # Extract complete JPEG frames
      while (start_idx = buffer.index(frame_start))
        end_idx = buffer.index(frame_end, start_idx + 2)
        break unless end_idx

        # Extract frame (including EOI marker)
        frame = buffer.slice!(0, end_idx + 2)
        next if frame.size < 100 # Skip invalid frames

        broadcast_frame(frame)
      end

      # Keep last incomplete frame in buffer
      buffer = buffer[-10_000..] || String.new if buffer.size > 20_000
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
server.start
