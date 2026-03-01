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
    move_to(@current_angle)
    @logger.info "ServoController initialized at #{@current_angle} degrees"
  end

  # Moves servo to specific angle
  #
  # @param angle [Integer] Target angle in degrees (0-180)
  #
  # @return [void]
  def move_to(angle)
    @current_angle = angle.clamp(@min_angle, @max_angle)
    pulse = angle_to_pulse(@current_angle)
    @pin.pwm.servo_pulsewidth = pulse
    @logger.debug "Servo moved to #{@current_angle} degrees (pulse: #{pulse}µs)"
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

  private

  # Loads servo settings from configuration hash
  #
  # @param settings [Hash] Configuration hash with servo settings
  # @return [void]
  #
  # @api private
  def load_settings(settings)
    @min_pulse = settings['servo_min_pulse'] || 500
    @max_pulse = settings['servo_max_pulse'] || 2400
    @min_angle = settings['servo_min_angle'] || 0
    @max_angle = settings['servo_max_angle'] || 180
    @step_angle = settings['servo_step_angle'] || 10
    @default_angle = settings['servo_default_angle'] || 90
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
end
