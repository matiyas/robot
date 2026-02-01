#!/usr/bin/env ruby
# frozen_string_literal: true

require 'socket'
require 'fcntl'

# MJPEG HTTP server for streaming video frames from rpicam-vid to web browsers
#
# This server implements the multipart/x-mixed-replace protocol to stream MJPEG
# video to multiple concurrent clients. It reads JPEG frames from a stream source
# (typically a FIFO or stdin), extracts individual frames by detecting JPEG markers,
# and broadcasts them to all connected HTTP clients.
#
# The server handles:
# - Frame synchronization (starting mid-stream)
# - Multiple simultaneous clients
# - Buffer management for variable frame sizes
# - Automatic client cleanup on disconnection
# - Thread-safe client list management
#
# @example Starting server with FIFO input
#   server = MjpegServer.new
#   stream_source = File.open('/tmp/camera_stream', 'rb')
#   server.start(stream_source)
#
# @example Starting server with stdin
#   server = MjpegServer.new
#   server.start($stdin)
#
# @example Streaming from rpicam-vid via FIFO
#   # Terminal 1: Create FIFO and start rpicam-vid
#   mkfifo /tmp/camera_stream
#   rpicam-vid --codec mjpeg -o /tmp/camera_stream
#
#   # Terminal 2: Start MJPEG server
#   ruby mjpeg-server.rb /tmp/camera_stream
#
#   # Browser: Access stream
#   http://localhost:8081
#
# @see https://github.com/matiyas/robot/blob/main/VIDEO_STREAMING.md Full architecture documentation
# @author Robot Tank Control Team
# @version 1.0.0
class MjpegServer
  # HTTP multipart boundary marker used to separate frames in the stream
  # This is part of the multipart/x-mixed-replace protocol
  # @return [String] the boundary string used in HTTP headers
  BOUNDARY = 'FRAME'

  # TCP port number where the HTTP server listens for client connections
  # @return [Integer] the port number (8081)
  PORT = 8081

  # JPEG Start of Image marker (SOI)
  # This byte sequence marks the beginning of every JPEG file
  # @return [String] binary string "\xFF\xD8" with ASCII-8BIT encoding
  FRAME_START = "\xff\xd8".b

  # JPEG End of Image marker (EOI)
  # This byte sequence marks the end of every JPEG file
  # @return [String] binary string "\xFF\xD9" with ASCII-8BIT encoding
  FRAME_END = "\xff\xd9".b

  # Minimum valid frame size in bytes
  # Frames smaller than this are considered corrupt and discarded
  # @return [Integer] minimum frame size (100 bytes)
  MIN_FRAME_SIZE = 100

  # Maximum buffer size before trimming
  # When buffer exceeds this size, it's trimmed to BUFFER_TRIM_SIZE
  # @return [Integer] maximum buffer size (100,000 bytes / ~100KB)
  MAX_BUFFER_SIZE = 100_000

  # Target size after buffer trimming
  # Buffer is reduced to this size when MAX_BUFFER_SIZE is exceeded
  # @return [Integer] buffer trim size (50,000 bytes / ~50KB)
  BUFFER_TRIM_SIZE = 50_000

  # Maximum buffer size before declaring error
  # If buffer exceeds this without finding frame end marker, it's cleared
  # @return [Integer] maximum error buffer size (200,000 bytes / ~200KB)
  MAX_ERROR_BUFFER = 200_000

  # Creates a new MJPEG server instance
  #
  # Initializes the TCP server, thread-safe client list, and configures
  # stdout/stderr for immediate output (unbuffered). The server listens
  # on all interfaces (0.0.0.0) on port 8081.
  #
  # @note This does not start accepting connections. Call {#start} to begin serving.
  # @raise [Errno::EADDRINUSE] if port 8081 is already in use
  # @raise [Errno::EACCES] if insufficient permissions to bind to port
  #
  # @example Create and start server
  #   server = MjpegServer.new
  #   server.start(File.open('/tmp/camera_stream', 'rb'))
  def initialize
    @clients = []
    @mutex = Mutex.new
    @server = TCPServer.new('0.0.0.0', PORT)
    $stdout.sync = true
    $stderr.sync = true
    puts "MJPEG Server starting on port #{PORT}..."
  end

  # Starts the MJPEG server and begins reading from the stream source
  #
  # This method:
  # 1. Spawns a background thread to accept client connections
  # 2. Reads MJPEG frames from the stream source
  # 3. Synchronizes to the first frame boundary
  # 4. Broadcasts frames to all connected clients
  #
  # This is a blocking call that runs until the stream source closes or an error occurs.
  #
  # @param stream_source [IO] the input stream to read MJPEG data from
  #   Can be any IO object ($stdin, File, FIFO, pipe, etc.)
  # @return [void]
  #
  # @example Start with FIFO
  #   server = MjpegServer.new
  #   fifo = File.open('/tmp/camera_stream', 'rb')
  #   server.start(fifo)
  #
  # @example Start with stdin
  #   server = MjpegServer.new
  #   server.start($stdin)
  #
  # @note This method blocks until the stream ends or an error occurs
  # @see #read_and_broadcast_stream for stream processing details
  def start(stream_source = $stdin)
    Thread.new { accept_clients }
    read_and_broadcast_stream(stream_source)
  end

  private

  # Continuously accepts incoming client connections
  #
  # Runs in a background thread spawned by {#start}. For each accepted connection,
  # spawns a new thread to handle that client via {#handle_client}.
  #
  # This is an infinite loop that only terminates if the server socket is closed
  # or an exception occurs.
  #
  # @return [void]
  # @note This method runs in a background thread
  # @see #handle_client for client connection handling
  def accept_clients
    loop do
      client = @server.accept
      Thread.new { handle_client(client) }
    end
  end

  # Handles a single client connection
  #
  # Performs the complete client lifecycle:
  # 1. Reads and discards the HTTP request headers
  # 2. Sends HTTP response headers for multipart streaming
  # 3. Registers client in the broadcast list
  # 4. Keeps thread alive (actual streaming happens in broadcast_frame)
  # 5. Cleans up on disconnection or error
  #
  # The thread sleeps indefinitely after setup. Disconnection is detected
  # when frame writes fail in {#broadcast_frame}.
  #
  # @param client [TCPSocket] the connected client socket
  # @return [void]
  #
  # @note This method runs in a per-client thread
  # @note Client disconnection is detected via write failures, not read timeouts
  # @see #discard_http_request for HTTP request handling
  # @see #send_http_headers for response header generation
  # @see #register_client for client list management
  # @see #unregister_client for cleanup
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

  # Reads and discards the HTTP request from the client
  #
  # HTTP clients send a GET request with headers. We don't need to parse these
  # for our simple streaming use case, so we read until we encounter a blank line
  # (which indicates end of headers) and discard everything.
  #
  # @param client [TCPSocket] the client socket to read from
  # @return [void]
  #
  # @example Typical HTTP request (discarded)
  #   GET / HTTP/1.1
  #   Host: localhost:8081
  #   User-Agent: Mozilla/5.0
  #   Accept: */*
  #   [blank line]
  #
  # @note This prevents the request from accumulating in the socket buffer
  def discard_http_request(client)
    loop do
      line = client.gets
      break if line.nil? || line.strip.empty?
    end
  end

  # Sends HTTP response headers to the client
  #
  # Sends the headers required for multipart/x-mixed-replace streaming:
  # - HTTP 200 OK status
  # - Content-Type with multipart boundary
  # - Connection: close (client should not reuse connection)
  #
  # After headers are sent, the socket is flushed to ensure immediate delivery.
  #
  # @param client [TCPSocket] the client socket to write to
  # @return [void]
  #
  # @example Headers sent
  #   HTTP/1.1 200 OK
  #   Content-Type: multipart/x-mixed-replace; boundary=FRAME
  #   Connection: close
  #   [blank line]
  #
  # @see https://en.wikipedia.org/wiki/MIME#Multipart_messages for multipart protocol
  def send_http_headers(client)
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Type: multipart/x-mixed-replace; boundary=#{BOUNDARY}\r\n")
    client.write("Connection: close\r\n\r\n")
    client.flush
  end

  # Adds a client to the broadcast list
  #
  # Thread-safely adds the client socket to @clients array. All clients in
  # this list receive frame broadcasts via {#broadcast_frame}.
  #
  # @param client [TCPSocket] the client socket to register
  # @return [void]
  #
  # @note This operation is thread-safe via @mutex
  # @note Logs the new client count
  # @see #unregister_client for removal
  # @see #broadcast_frame for frame distribution
  def register_client(client)
    @mutex.synchronize { @clients << client }
    puts "Client connected (#{@clients.size} total)"
  end

  # Removes a client from the broadcast list and closes the socket
  #
  # Thread-safely removes the client from @clients array and ensures the socket
  # is closed. This is called when a client disconnects or encounters an error.
  #
  # @param client [TCPSocket] the client socket to unregister
  # @return [void]
  #
  # @note This operation is thread-safe via @mutex
  # @note Logs the remaining client count
  # @note Safe to call multiple times (idempotent close check)
  # @see #register_client for addition
  def unregister_client(client)
    @mutex.synchronize { @clients.delete(client) }
    client.close unless client.closed?
    puts "Client disconnected (#{@clients.size} remaining)"
  end

  # Reads MJPEG stream and broadcasts frames to all clients
  #
  # This is the main processing pipeline:
  # 1. Synchronize to first frame boundary
  # 2. Continuously read data from stream
  # 3. Extract complete JPEG frames
  # 4. Broadcast frames to all clients
  #
  # Uses binary encoding (ASCII-8BIT) to preserve JPEG byte values.
  #
  # @param stream_source [IO] the input stream containing MJPEG data
  # @return [void]
  #
  # @note Blocks until stream ends or error occurs
  # @note Buffer uses ASCII-8BIT encoding for binary data
  # @see #sync_to_first_frame for initial synchronization
  # @see #process_stream for main processing loop
  def read_and_broadcast_stream(stream_source)
    buffer = String.new(encoding: 'ASCII-8BIT')
    frame_count = 0

    sync_to_first_frame(stream_source, buffer)
    return unless buffer.size.positive?

    process_stream(stream_source, buffer, frame_count)
  end

  # Synchronizes to the first JPEG frame boundary in the stream
  #
  # When starting mid-stream, we might begin reading in the middle of a frame.
  # This method scans the input until it finds a JPEG Start of Image marker,
  # then copies everything from that marker onward to the main buffer.
  #
  # This ensures processing always starts at a frame boundary, preventing
  # initial frame corruption.
  #
  # @param stream_source [IO] the input stream to read from
  # @param buffer [String] the main buffer to populate with synchronized data
  # @return [void]
  #
  # @note Modifies buffer in-place
  # @note Uses separate sync_buffer to avoid polluting main buffer
  # @see #read_until_frame_marker for marker detection
  # @see #copy_synced_buffer_to_main for buffer transfer
  def sync_to_first_frame(stream_source, buffer)
    puts 'Starting to read MJPEG stream...'
    puts 'Syncing to first JPEG frame...'

    sync_buffer = String.new(encoding: 'ASCII-8BIT')
    sync_buffer = read_until_frame_marker(stream_source, sync_buffer)

    copy_synced_buffer_to_main(sync_buffer, buffer)
  end

  # Reads from stream until FRAME_START marker is found
  #
  # Continuously reads 4KB chunks and accumulates them in sync_buffer until
  # the JPEG Start of Image marker is detected. Buffer is trimmed periodically
  # to prevent excessive memory usage during synchronization.
  #
  # @param stream_source [IO] the input stream to read from
  # @param sync_buffer [String] buffer to accumulate data during sync
  # @return [String] the sync_buffer containing at least one FRAME_START marker
  #
  # @note Reads in 4KB chunks for efficiency
  # @note Trims buffer if it exceeds 16KB
  # @see #trim_sync_buffer for buffer size management
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

  # Trims the synchronization buffer to prevent excessive memory usage
  #
  # During synchronization, we might read significant data before finding the
  # first frame marker. This method keeps only the last 8KB when buffer exceeds
  # 16KB, ensuring we don't accumulate unlimited data while still maintaining
  # enough context to find the marker.
  #
  # @param sync_buffer [String] the buffer to trim
  # @return [String] the original buffer if ≤16KB, or last 8KB if larger
  #
  # @note Keeps last 8KB to ensure marker isn't split across trim boundary
  def trim_sync_buffer(sync_buffer)
    sync_buffer.size > 16_384 ? (sync_buffer[-8192..] || sync_buffer) : sync_buffer
  end

  # Copies synchronized data from sync buffer to main processing buffer
  #
  # After finding the first frame marker, copies everything from that marker
  # onward to the main buffer. This ensures the main buffer starts at a clean
  # frame boundary.
  #
  # @param sync_buffer [String] the synchronization buffer containing FRAME_START
  # @param buffer [String] the main processing buffer to populate
  # @return [void]
  #
  # @note Modifies buffer in-place
  # @note If no marker found, buffer remains empty (error condition)
  def copy_synced_buffer_to_main(sync_buffer, buffer)
    start_pos = sync_buffer.index(FRAME_START)
    if start_pos
      buffer << sync_buffer[start_pos..]
      puts 'Synced! Found first frame marker, starting processing...'
    else
      puts 'ERROR: Could not sync to JPEG stream'
    end
  end

  # Main stream processing loop
  #
  # Continuously reads data from stream, extracts complete frames, and broadcasts
  # them to clients. Handles EOF conditions with retry logic for FIFO behavior
  # (where writer might not be connected yet).
  #
  # The loop:
  # 1. Reads 4KB chunks from stream
  # 2. Accumulates in buffer
  # 3. Extracts complete frames (FRAME_START to FRAME_END)
  # 4. Broadcasts frames to all clients
  # 5. Trims buffer to prevent unbounded growth
  #
  # @param stream_source [IO] the input stream to read from
  # @param buffer [String] the accumulation buffer (modified in-place)
  # @param frame_count [Integer] the current frame counter
  # @return [void]
  #
  # @note Retries up to 10 times on EOF (for FIFO writer startup)
  # @note Reads in 4KB chunks for efficiency
  # @see #extract_and_broadcast_frames for frame extraction
  # @see #trim_buffer for buffer management
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

  # Extracts and broadcasts all complete frames from buffer
  #
  # Searches buffer for complete JPEG frames (FRAME_START to FRAME_END) and
  # processes each one. Frames are removed from buffer after extraction to
  # prevent reprocessing.
  #
  # Handles incomplete frames by leaving them in buffer for next iteration.
  # Detects buffer overflow conditions (frame too large or corrupt stream).
  #
  # @param buffer [String] the buffer containing accumulated stream data
  # @param frame_count [Integer] the current frame counter
  # @return [Integer] updated frame count after processing
  #
  # @note Modifies buffer in-place (removes extracted frames)
  # @note Stops processing when no complete frame found (incomplete frame in buffer)
  # @see #buffer_overflow? for overflow detection
  # @see #process_frame for individual frame handling
  def extract_and_broadcast_frames(buffer, frame_count)
    while (start_idx = buffer.index(FRAME_START))
      end_idx = buffer.index(FRAME_END, start_idx + 2)
      break unless end_idx || buffer_overflow?(buffer, start_idx)

      frame = buffer.slice!(0, end_idx + 2)
      frame_count = process_frame(frame, frame_count)
    end
    frame_count
  end

  # Checks for buffer overflow condition
  #
  # If buffer grows beyond MAX_ERROR_BUFFER without finding a frame end marker,
  # this indicates a corrupt stream or abnormally large frame. The buffer is
  # cleared to prevent unbounded memory growth.
  #
  # @param buffer [String] the buffer to check
  # @param start_idx [Integer] position of last FRAME_START found
  # @return [Boolean] true if overflow occurred and buffer was cleared
  #
  # @note Modifies buffer (clears it) if overflow detected
  # @note Logs error with buffer size and marker position
  def buffer_overflow?(buffer, start_idx)
    return false if buffer.size <= MAX_ERROR_BUFFER

    puts "ERROR: Buffer size #{buffer.size}, frame start at #{start_idx}, still no end marker"
    buffer.clear
    true
  end

  # Processes a single extracted frame
  #
  # Validates frame size, increments counter, logs progress, and broadcasts
  # to all clients. Frames below MIN_FRAME_SIZE are considered corrupt and skipped.
  #
  # @param frame [String] the complete JPEG frame (including SOI and EOI markers)
  # @param frame_count [Integer] the current frame counter
  # @return [Integer] updated frame count (incremented if frame was valid)
  #
  # @note Logs every 100th frame to avoid excessive output
  # @see #broadcast_frame for distribution to clients
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

  # Trims buffer to prevent unbounded growth
  #
  # When buffer exceeds MAX_BUFFER_SIZE, keeps only the last BUFFER_TRIM_SIZE
  # bytes. This maintains enough data to complete the current frame while
  # discarding old data.
  #
  # @param buffer [String] the buffer to trim (modified in-place)
  # @return [void]
  #
  # @note Only trims when buffer exceeds 100KB
  # @note Keeps last 50KB after trimming
  # @note Ensures we don't discard incomplete frame at end of buffer
  def trim_buffer(buffer)
    buffer.replace(buffer[-BUFFER_TRIM_SIZE..] || +'') if buffer.size > MAX_BUFFER_SIZE
  end

  # Broadcasts a frame to all connected clients
  #
  # Thread-safely iterates through all clients and sends the frame using the
  # multipart/x-mixed-replace protocol. If a client write fails (disconnected
  # or error), that client is removed from the list.
  #
  # All client operations are protected by @mutex to prevent race conditions
  # when clients connect/disconnect during broadcast.
  #
  # @param frame [String] the JPEG frame data to broadcast
  # @return [void]
  #
  # @note Thread-safe via @mutex
  # @note Failed clients are automatically removed
  # @note Catches and logs all errors without stopping broadcast to other clients
  # @see #send_frame_to_client for frame transmission protocol
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

  # Sends a single frame to a client using multipart protocol
  #
  # Writes the frame with proper multipart/x-mixed-replace headers:
  # 1. Boundary marker (--FRAME)
  # 2. Content-Type header (image/jpeg)
  # 3. Content-Length header (frame size in bytes)
  # 4. Blank line (end of headers)
  # 5. JPEG frame data
  # 6. Trailing CRLF
  #
  # Socket is flushed after write to ensure immediate delivery.
  #
  # @param client [TCPSocket] the client socket to write to
  # @param frame [String] the JPEG frame data
  # @return [void]
  #
  # @raise [Errno::EPIPE] if client has disconnected (broken pipe)
  # @raise [Errno::ECONNRESET] if connection reset by peer
  # @raise [IOError] if socket is closed
  #
  # @example Frame transmission format
  #   --FRAME
  #   Content-Type: image/jpeg
  #   Content-Length: 41234
  #
  #   [JPEG binary data]
  #
  # @see https://en.wikipedia.org/wiki/MIME#Multipart_messages
  def send_frame_to_client(client, frame)
    client.write("--#{BOUNDARY}\r\n")
    client.write("Content-Type: image/jpeg\r\n")
    client.write("Content-Length: #{frame.bytesize}\r\n\r\n")
    client.write(frame)
    client.write("\r\n")
    client.flush
  end
end

# Main script execution
#
# Creates and starts an MJPEG server instance. If a command-line argument is
# provided, treats it as a FIFO path. Otherwise, reads from stdin.
#
# @example Run with FIFO
#   ruby mjpeg-server.rb /tmp/camera_stream
#
# @example Run with stdin
#   rpicam-vid --codec mjpeg -o - | ruby mjpeg-server.rb
#
# @note This script runs indefinitely until terminated (Ctrl+C) or stream closes
# @note Server listens on port 8081
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
