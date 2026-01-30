# frozen_string_literal: true

# High-level robot orchestration model
#
# Provides the business logic layer between the API and hardware control.
# This class validates inputs, enforces safety limits, and delegates to the
# appropriate controller implementation (GPIO or Mock).
#
# The Robot class acts as a facade, providing a clean interface for robot
# operations while handling duration validation, timeout enforcement, and
# error handling. It never directly interacts with hardware - all GPIO
# operations are delegated to the controller.
#
# @example Creating a robot instance
#   controller = GpioController.new(gpio_manager, logger)
#   settings = { 'movement_timeout' => 5000, 'turret_timeout' => 2000 }
#   robot = Robot.new(controller, settings, logger)
#
# @example Moving the robot
#   robot.move('forward', duration: 1000)
#   # => { action: "forward", duration: 1000 }
#
# @see ControlInterface Base class for controller implementations
# @see GpioController Hardware controller implementation
# @see MockController Testing controller implementation
class Robot
  # @!attribute [r] controller
  #   @return [ControlInterface] The controller implementation (GPIO or Mock)
  attr_reader :controller

  # Initializes a new Robot instance
  #
  # @param controller [ControlInterface] The controller implementation to use
  # @param settings [Hash] Configuration hash with timeout values
  # @option settings [Integer] 'movement_timeout' Maximum movement duration in ms
  # @option settings [Integer] 'turret_timeout' Maximum turret rotation duration in ms
  # @param logger [Logger, nil] Logger instance for output (default: stdout)
  #
  # @return [Robot] A new robot instance
  def initialize(controller, settings, logger = nil)
    @controller = controller
    @settings = settings
    @logger = logger || Logger.new($stdout)
  end

  # Moves the robot in the specified direction
  #
  # Controls robot movement with automatic safety limiting. Validates the
  # direction, enforces duration limits, and delegates to the appropriate
  # controller method. Tank turning is used for left/right movements.
  #
  # Movement directions:
  # - 'forward': Both motors forward
  # - 'backward': Both motors backward
  # - 'left': Tank turn (left motor backward, right motor forward)
  # - 'right': Tank turn (left motor forward, right motor backward)
  #
  # @param direction [String] Movement direction: 'forward', 'backward', 'left', 'right'
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [Hash] Action details with keys :action and :duration
  #
  # @raise [ArgumentError] If direction is invalid or duration is non-positive
  #
  # @example Move forward for 1 second
  #   robot.move('forward', duration: 1000)
  #   # => { action: "forward", duration: 1000 }
  #
  # @example Continuous movement (until stopped)
  #   robot.move('backward')
  #   # => { action: "backward", duration: nil }
  def move(direction, duration: nil)
    duration = validate_and_limit_duration(duration, @settings['movement_timeout'])

    case direction
    when 'forward'
      @controller.move_forward(duration: duration)
    when 'backward'
      @controller.move_backward(duration: duration)
    when 'left'
      @controller.turn_left(duration: duration)
    when 'right'
      @controller.turn_right(duration: duration)
    else
      raise ArgumentError, "Invalid direction: #{direction}"
    end

    { action: direction, duration: duration }
  end

  # Rotates the camera turret
  #
  # Controls the turret motor to rotate the camera left or right.
  # The turret operates independently from the wheel motors and has
  # its own timeout limit for safety.
  #
  # @param direction [String] Rotation direction: 'left' or 'right'
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [Hash] Action details with keys :action and :duration
  #
  # @raise [ArgumentError] If direction is invalid or duration is non-positive
  #
  # @example Rotate turret left for 500ms
  #   robot.turret('left', duration: 500)
  #   # => { action: "turret_left", duration: 500 }
  def turret(direction, duration: nil)
    duration = validate_and_limit_duration(duration, @settings['turret_timeout'])

    case direction
    when 'left'
      @controller.turret_left(duration: duration)
    when 'right'
      @controller.turret_right(duration: duration)
    else
      raise ArgumentError, "Invalid turret direction: #{direction}"
    end

    { action: "turret_#{direction}", duration: duration }
  end

  # Emergency stop for all motors
  #
  # Immediately stops all motor movement by calling the controller's
  # stop_motors method. This sets all motor pins to coast mode (LOW).
  #
  # @return [Hash] Action details with key :action set to 'stop_all'
  #
  # @example Emergency stop
  #   robot.stop
  #   # => { action: "stop_all" }
  def stop
    @controller.stop_motors
    { action: 'stop_all' }
  end

  # Returns current robot status
  #
  # Provides status information including connection state, GPIO enablement,
  # and camera URL from settings.
  #
  # @return [Hash] Status information with keys:
  #   - connected: [Boolean] Always true (robot is connected)
  #   - gpio_enabled: [Boolean] Whether GPIO hardware is enabled
  #   - camera_url: [String] URL for camera stream
  #
  # @example Get robot status
  #   robot.status
  #   # => { connected: true, gpio_enabled: true, camera_url: "http://..." }
  def status
    {
      connected: true,
      gpio_enabled: @settings['gpio_enabled'],
      camera_url: @settings['camera_url']
    }
  end

  private

  # Validates and enforces duration limits
  #
  # Ensures duration is positive and doesn't exceed the configured maximum.
  # If duration exceeds the maximum, it's automatically limited and a warning
  # is logged. Nil durations are allowed for continuous movement.
  #
  # @param duration [Integer, nil] Requested duration in milliseconds
  # @param max_duration [Integer] Maximum allowed duration in milliseconds
  #
  # @return [Integer, nil] Validated and limited duration, or nil
  #
  # @raise [ArgumentError] If duration is zero or negative
  #
  # @api private
  def validate_and_limit_duration(duration, max_duration)
    return nil if duration.nil?

    duration = duration.to_i
    raise ArgumentError, 'Duration must be positive' if duration <= 0

    if duration > max_duration
      @logger.warn "Duration #{duration}ms exceeds max #{max_duration}ms, limiting"
      duration = max_duration
    end

    duration
  end
end
