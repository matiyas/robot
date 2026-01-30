# frozen_string_literal: true

require 'json'

# Helper methods for API request/response handling
#
# This module provides utility methods for Sinatra applications to handle
# JSON API responses, input validation, and error formatting. It's included
# in the RobotApp class to make these methods available to all routes.
#
# Features:
# - Consistent JSON response formatting
# - Success/error response helpers
# - Direction validation for robot movements
# - JSON body parsing with error handling
#
# @example Including in a Sinatra app
#   class RobotApp < Sinatra::Base
#     helpers ApiHelpers
#   end
#
# @example Using in a route
#   post '/api/v1/move' do
#     data = parse_json_body
#     validate_direction(data['direction'], %w[forward backward left right])
#     success_response(action: 'move', direction: data['direction'])
#   end
module ApiHelpers
  # Sends a JSON response with specified data and status code
  #
  # Sets the Content-Type header to application/json, sets the HTTP status,
  # and converts the data to JSON format.
  #
  # @param data [Hash, Array] Data to be converted to JSON
  # @param status [Integer] HTTP status code (default: 200)
  #
  # @return [String] JSON-formatted response body
  #
  # @example Success response
  #   json_response({ message: "OK" }, 200)
  #   # => '{"message":"OK"}' with status 200
  #
  # @example Error response
  #   json_response({ error: "Not found" }, 404)
  #   # => '{"error":"Not found"}' with status 404
  def json_response(data, status = 200)
    content_type :json
    status status
    data.to_json
  end

  # Sends a success JSON response
  #
  # Convenience method for sending a successful API response. Automatically
  # adds a `success: true` field and merges any additional data.
  #
  # @param data [Hash] Additional data to include in response (default: {})
  #
  # @return [String] JSON-formatted success response
  #
  # @example Simple success
  #   success_response
  #   # => '{"success":true}'
  #
  # @example Success with data
  #   success_response(action: 'move', direction: 'forward')
  #   # => '{"success":true,"action":"move","direction":"forward"}'
  def success_response(data = {})
    json_response({ success: true }.merge(data))
  end

  # Sends an error JSON response
  #
  # Convenience method for sending an error API response. Automatically
  # adds a `success: false` field and includes the error message.
  #
  # @param message [String] Error message to include in response
  # @param status [Integer] HTTP status code (default: 400)
  #
  # @return [String] JSON-formatted error response
  #
  # @example Client error
  #   error_response("Invalid direction", 400)
  #   # => '{"success":false,"error":"Invalid direction"}' with status 400
  #
  # @example Server error
  #   error_response("Internal error", 500)
  #   # => '{"success":false,"error":"Internal error"}' with status 500
  def error_response(message, status = 400)
    json_response({ success: false, error: message }, status)
  end

  # Validates a direction parameter against allowed values
  #
  # Checks if the provided direction is in the list of valid directions.
  # If invalid, immediately halts the request with a 400 error response.
  #
  # @param direction [String] The direction to validate
  # @param valid_directions [Array<String>] List of valid direction strings
  #
  # @return [void] Returns nothing if valid, halts request if invalid
  #
  # @raise [Sinatra::Halt] Halts with 400 error if direction is invalid
  #
  # @example Validate movement direction
  #   validate_direction('forward', %w[forward backward left right])
  #   # Returns nothing, validation passes
  #
  # @example Invalid direction
  #   validate_direction('sideways', %w[forward backward left right])
  #   # Halts with error: "Invalid direction. Must be one of: forward, backward, left, right"
  def validate_direction(direction, valid_directions)
    return if valid_directions.include?(direction)

    halt 400, error_response("Invalid direction. Must be one of: #{valid_directions.join(', ')}")
  end

  # Parses JSON from the request body
  #
  # Reads and parses the JSON body from the incoming HTTP request.
  # Handles parse errors gracefully by halting with a 400 error.
  #
  # @return [Hash] Parsed JSON as a Ruby hash
  #
  # @raise [Sinatra::Halt] Halts with 400 error if JSON is malformed
  #
  # @example Parse JSON request
  #   data = parse_json_body
  #   direction = data['direction']
  #   duration = data['duration']
  def parse_json_body
    request.body.rewind
    JSON.parse(request.body.read)
  rescue JSON::ParserError
    halt 400, error_response('Invalid JSON in request body')
  end
end
