# frozen_string_literal: true

# Controls SG90 servo motor for turret positioning
#
# SG90 Servo Specifications:
# - PWM frequency: 50Hz (20ms period)
# - Pulse width: 0.5ms (0 degrees) to 2.4ms (180 degrees)
#
# This class uses pigpio's pwm.servo_pulsewidth accessor which accepts
# pulse width in microseconds directly, handling the 50Hz frequency internally.
#
# The servo position is controlled by pulse width:
# - 500µs  -> 0 degrees (full left)
# - 1450µs -> 90 degrees (center)
# - 2400µs -> 180 degrees (full right)
#
# @example Initialize and control servo
#   servo = ServoController.new(gpio_pin, settings, logger)
#   servo.set_angle(90)    # Center position
#   servo.step_left        # Move 10 degrees left
#   servo.step_right       # Move 10 degrees right
#
# @see GpioController Uses ServoController for turret operations
class ServoController
  # @return [Integer] Current servo angle in degrees
  attr_reader :current_angle

  # Initializes the servo controller
  #
  # @param gpio_pin [Pigpio::IF::GPIO] GPIO pin object for servo signal
  # @param settings [Hash] Configuration hash with servo settings
  # @param logger [Logger, nil] Logger instance for debugging
  #
  # @return [ServoController] A new servo controller instance
  def initialize(gpio_pin, settings, logger = nil)
    @pin = gpio_pin
    @settings = settings
    @logger = logger || Logger.new($stdout)
    load_settings(settings)
    @current_angle = @default_angle
    move_to(@current_angle, smooth: false)
    @logger.info "ServoController initialized at #{@current_angle} degrees"
  end

  # Moves servo to specific angle with smooth interpolation
  #
  # @param angle [Integer] Target angle in degrees (0-180)
  # @param smooth [Boolean] Use smooth interpolation (default: true)
  #
  # @return [void]
  def move_to(angle, smooth: true)
    target = angle.clamp(@min_angle, @max_angle)

    if smooth && target != @current_angle
      smooth_move(@current_angle, target)
    else
      apply_angle(target)
    end
  end

  # Steps servo left by configured step angle
  #
  # Decreases the current angle by step_angle degrees, clamped to min_angle.
  #
  # @return [void]
  def step_left
    target = @current_angle - @step_angle
    move_to(target)
    @logger.debug "Servo stepped left to #{@current_angle} degrees"
  end

  # Steps servo right by configured step angle
  #
  # Increases the current angle by step_angle degrees, clamped to max_angle.
  #
  # @return [void]
  def step_right
    target = @current_angle + @step_angle
    move_to(target)
    @logger.debug "Servo stepped right to #{@current_angle} degrees"
  end

  # Centers the servo to default position
  #
  # @return [void]
  def center
    move_to(@default_angle)
    @logger.debug 'Servo centered'
  end

  # Stops servo movement and holds current position
  #
  # Servo naturally holds position when receiving constant PWM signal.
  #
  # @return [void]
  def stop
    # Servo holds position naturally, nothing to do
  end

  # Releases servo by stopping PWM signal
  #
  # Setting pulsewidth to 0 stops the PWM signal, allowing the servo
  # to be manually moved (it will not hold position).
  #
  # @return [void]
  def release
    @pin.pwm.servo_pulsewidth = 0
    @logger.debug 'Servo released'
  end

  # Cleans up servo resources
  #
  # @return [void]
  def cleanup
    release
    @logger.info 'ServoController cleanup'
  end

  SETTING_DEFAULTS = {
    'servo_min_pulse' => 500,
    'servo_max_pulse' => 2400,
    'servo_min_angle' => 0,
    'servo_max_angle' => 180,
    'servo_step_angle' => 10,
    'servo_default_angle' => 90,
    'servo_smooth_step' => 2,
    'servo_smooth_delay_ms' => 15
  }.freeze

  private

  # Loads servo settings from configuration hash
  #
  # @param settings [Hash] Configuration hash with servo settings
  # @return [void]
  #
  # @api private
  def load_settings(settings)
    config = SETTING_DEFAULTS.merge(settings || {})
    @min_pulse = config['servo_min_pulse']
    @max_pulse = config['servo_max_pulse']
    @min_angle = config['servo_min_angle']
    @max_angle = config['servo_max_angle']
    @step_angle = config['servo_step_angle']
    @default_angle = config['servo_default_angle']
    @smooth_step_degrees = config['servo_smooth_step']
    @smooth_step_delay_ms = config['servo_smooth_delay_ms']
  end

  # Converts angle to pulse width in microseconds
  #
  # Uses linear interpolation to map angle range to pulse width range.
  #
  # @param angle [Integer] Angle in degrees
  # @return [Integer] Pulse width in microseconds
  #
  # @api private
  def angle_to_pulse(angle)
    pulse_range = @max_pulse - @min_pulse
    angle_range = @max_angle - @min_angle
    ratio = (angle - @min_angle).to_f / angle_range
    (@min_pulse + (ratio * pulse_range)).to_i
  end

  # Sets angle immediately without interpolation
  #
  # @param angle [Integer] Target angle in degrees
  # @return [void]
  #
  # @api private
  def apply_angle(angle)
    @current_angle = angle
    pulse = angle_to_pulse(@current_angle)
    @pin.pwm.servo_pulsewidth = pulse
    @logger.debug "Servo moved to #{@current_angle} degrees (pulse: #{pulse}µs)"
  end

  # Smoothly interpolates servo from current to target angle
  #
  # @param from_angle [Integer] Starting angle
  # @param to_angle [Integer] Target angle
  # @return [void]
  #
  # @api private
  def smooth_move(from_angle, to_angle)
    direction = to_angle > from_angle ? 1 : -1
    current = from_angle

    while (direction.positive? && current < to_angle) || (direction.negative? && current > to_angle)
      current += direction * @smooth_step_degrees
      current = direction.positive? ? [current, to_angle].min : [current, to_angle].max
      apply_angle(current)
      sleep(@smooth_step_delay_ms / 1000.0)
    end

    @logger.debug "Servo smoothly moved to #{@current_angle} degrees"
  end
end
