# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/json'
require 'logger'
require 'yaml'

require_relative '../lib/gpio_manager'
require_relative '../lib/safety_handler'
require_relative 'services/control_interface'
require_relative 'services/mock_controller'
require_relative 'services/gpio_controller'
require_relative 'services/pwm_ramper'
require_relative 'models/robot'
require_relative 'helpers/api_helpers'

# RobotApp is the main Sinatra application for the robot tank control system.
#
# This application provides both a web UI and a RESTful API for controlling
# a Raspberry Pi-based robot tank. It manages GPIO controllers, handles HTTP
# requests, and coordinates robot movements through a clean service architecture.
#
# The application supports two modes:
# - Production mode: Uses GPIO hardware control via GpioController
# - Development mode: Uses MockController for testing without hardware
#
# @example Starting the application
#   ruby app/robot_app.rb
#
# @example Using the API
#   # Move forward for 1 second
#   curl -X POST http://localhost:4567/api/v1/move \
#     -H "Content-Type: application/json" \
#     -d '{"direction":"forward","duration":1000}'
#
# @see Robot The business logic layer
# @see GpioController Hardware control implementation
# @see MockController Development mock implementation
class RobotApp < Sinatra::Base
  helpers ApiHelpers

  # Application configuration block
  #
  # Initializes all application components including:
  # - Environment-based settings from YAML configuration
  # - Logger with appropriate log level
  # - GPIO or Mock controller based on configuration
  # - Robot model instance
  # - Safety handler for signal trapping
  #
  # Configuration is loaded from config/settings.yml and selects the
  # appropriate environment section (development, production, etc.)
  configure do
    # Load settings
    env = ENV['RACK_ENV'] || 'development'
    settings_file = File.join(__dir__, '..', 'config', 'settings.yml')
    all_settings = YAML.load_file(settings_file, aliases: true)
    config = all_settings['default'].merge(all_settings[env] || {})

    set :environment, env.to_sym
    set :bind, config['host']
    set :port, config['port']
    set :app_settings, config
    set :public_folder, File.join(__dir__, '..', 'public')
    set :views, File.join(__dir__, '..', 'views')
    set :show_exceptions, false

    # Setup logger
    logger = Logger.new($stdout)
    logger.level = config['log_level'] == 'debug' ? Logger::DEBUG : Logger::INFO
    set :logger, logger

    # Initialize controller based on configuration
    controller =
      if config['gpio_enabled']
        logger.info 'Initializing GPIO controller'
        gpio_manager = GpioManager.new(File.join(__dir__, '..', 'config', 'gpio_pins.yml'), logger)

        # Create PWM ramper if enabled and PWM pins are available
        pwm_ramper =
          if config['pwm_enabled'] && gpio_manager.pwm_pins
            logger.info 'PWM soft-start enabled'
            PwmRamper.new(gpio_manager.pwm_pins, config, logger)
          end

        GpioController.new(gpio_manager, logger, pwm_ramper)
      else
        logger.info 'Initializing Mock controller (GPIO disabled)'
        MockController.new(logger, pwm_enabled: config['pwm_enabled'])
      end

    # Initialize robot
    robot = Robot.new(controller, config, logger)
    set :robot, robot

    # Setup safety handler
    SafetyHandler.setup(controller, logger)

    logger.info "RobotApp initialized in #{env} mode"
    logger.info "Server will start on #{config['host']}:#{config['port']}"
  end

  # Global error handler for unhandled exceptions
  #
  # Catches all StandardError exceptions, logs them with full backtrace,
  # and returns a JSON error response with 500 status code.
  #
  # @return [String] JSON error response
  error do
    e = env['sinatra.error']
    settings.logger.error "Error: #{e.message}"
    settings.logger.error e.backtrace.join("\n")
    error_response("Internal server error: #{e.message}", 500)
  end

  # Specific error handler for ArgumentError exceptions
  #
  # Catches validation errors (invalid directions, durations, etc.),
  # logs them as warnings, and returns a JSON error response with 400 status.
  #
  # @return [String] JSON error response
  error ArgumentError do
    e = env['sinatra.error']
    settings.logger.warn "Invalid argument: #{e.message}"
    error_response(e.message, 400)
  end

  # Authentication helper method for securing API endpoints
  #
  # Currently a no-op placeholder for future authentication implementation.
  # When enabled via auth_enabled setting, this method will be called before
  # all /api/* routes to verify user credentials.
  #
  # Potential implementations include:
  # - HTTP Basic Authentication
  # - JWT token validation
  # - Session-based authentication
  # - API key verification
  #
  # @return [void]
  # @raise [Sinatra::Halt] Will halt with 401 status when authentication fails
  #
  # @example Future implementation
  #   def authenticate!
  #     halt 401, error_response("Unauthorized") unless authorized?
  #   end
  def authenticate!
    # TODO: Implement authentication when needed
    # Options: HTTP Basic Auth, JWT tokens, or session cookies
    # halt 401, error_response("Unauthorized") unless authorized?
  end

  # Web UI Routes

  # Renders the main web control panel
  #
  # Serves the HTML interface for controlling the robot via a web browser.
  # The interface provides buttons for movement, turret control, and displays
  # camera feed if configured.
  #
  # @return [String] Rendered HTML from views/index.erb
  get '/' do
    erb :index
  end

  # API Routes

  # Before filter for all API endpoints
  #
  # Sets JSON content type for all API responses and calls authentication
  # if auth_enabled is configured in settings.
  #
  # @return [void]
  before '/api/*' do
    content_type :json
    authenticate! if settings.app_settings['auth_enabled']
  end

  # Controls robot movement in four directions
  #
  # Accepts a direction and optional duration to move the robot. The robot
  # will move in the specified direction either continuously (if no duration)
  # or for the specified duration in milliseconds.
  #
  # Tank turning is used for left/right movements:
  # - Left: left motor backward, right motor forward
  # - Right: left motor forward, right motor backward
  #
  # @note POST /api/v1/move
  #
  # @example Request body
  #   {
  #     "direction": "forward",
  #     "duration": 1000
  #   }
  #
  # @example Response
  #   {
  #     "success": true,
  #     "action": "forward",
  #     "duration": 1000
  #   }
  #
  # @return [String] JSON response with action details
  # @raise [ArgumentError] If direction is invalid
  post '/api/v1/move' do
    data = parse_json_body
    direction = data['direction']
    duration = data['duration']

    validate_direction(direction, %w[forward backward left right])

    result = settings.robot.move(direction, duration: duration)
    success_response(result)
  end

  # Controls turret rotation
  #
  # Rotates the camera turret left or right for the specified duration.
  # The turret motor is controlled independently from the wheel motors.
  #
  # @note POST /api/v1/turret
  #
  # @example Request body
  #   {
  #     "direction": "left",
  #     "duration": 500
  #   }
  #
  # @example Response
  #   {
  #     "success": true,
  #     "action": "turret_left",
  #     "duration": 500
  #   }
  #
  # @return [String] JSON response with action details
  # @raise [ArgumentError] If direction is not "left" or "right"
  post '/api/v1/turret' do
    data = parse_json_body
    direction = data['direction']
    duration = data['duration']

    validate_direction(direction, %w[left right])

    result = settings.robot.turret(direction, duration: duration)
    success_response(result)
  end

  # Emergency stop for all motors
  #
  # Immediately stops all motor movement (wheels and turret) by setting
  # all motor pins to LOW (coast mode). This is a safety feature that can
  # be called at any time to halt robot movement.
  #
  # @note POST /api/v1/stop
  #
  # @example Response
  #   {
  #     "success": true,
  #     "action": "stop_all"
  #   }
  #
  # @return [String] JSON response confirming stop
  post '/api/v1/stop' do
    result = settings.robot.stop
    success_response(result)
  end

  # Returns current robot status information
  #
  # Provides status information about the robot including connection state,
  # GPIO enablement, and camera configuration.
  #
  # @note GET /api/v1/status
  #
  # @example Response
  #   {
  #     "success": true,
  #     "connected": true,
  #     "gpio_enabled": true,
  #     "camera_url": "http://192.168.1.100:8081"
  #   }
  #
  # @return [String] JSON response with status details
  get '/api/v1/status' do
    status = settings.robot.status
    success_response(status)
  end

  # Returns camera stream URL
  #
  # Provides the URL for the camera video stream, typically served by
  # rpicam-vid or another streaming service running on the Raspberry Pi.
  #
  # @note GET /api/v1/camera
  #
  # @example Response
  #   {
  #     "success": true,
  #     "stream_url": "http://192.168.1.100:8081"
  #   }
  #
  # @return [String] JSON response with camera stream URL
  get '/api/v1/camera' do
    # Replace localhost with actual request host for browser compatibility
    camera_url = settings.app_settings['camera_url']
    dynamic_url = camera_url.gsub('localhost', request.host)
    success_response(stream_url: dynamic_url)
  end

  # Health check endpoint for monitoring
  #
  # Simple endpoint for health checks, monitoring, and load balancers.
  # Always returns 200 status with current timestamp.
  #
  # @note GET /health
  #
  # @example Response
  #   {
  #     "status": "ok",
  #     "timestamp": 1640000000
  #   }
  #
  # @return [String] JSON response with health status
  get '/health' do
    json_response(status: 'ok', timestamp: Time.now.to_i)
  end

  # Start the server if this file is executed directly
  run! if app_file == $PROGRAM_NAME
end
