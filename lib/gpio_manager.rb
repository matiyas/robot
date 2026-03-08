# frozen_string_literal: true

require 'yaml'
require 'pigpio'

# Manages GPIO pin initialization, configuration, and lifecycle
#
# This class handles all GPIO pin setup and teardown for the robot control
# system. It reads pin assignments from a YAML configuration file and
# initializes pigpio GPIO objects for controlling DRV8833 motor drivers.
#
# The GpioManager is responsible for:
# - Loading pin configuration from YAML
# - Creating GPIO objects for all motors
# - Setting initial safe state (all pins LOW)
# - Cleanup and reset on shutdown
#
# Each wheel motor uses two GPIO pins (IN1 and IN2) connected to a DRV8833
# H-bridge driver. Both DRV8833 drivers share a single enable pin (EEP wired
# together) for PWM speed control. The turret uses a single GPIO pin for
# SG90 servo control.
#
# Configuration file format (config/gpio_pins.yml):
#   motor_left:
#     in1: 17
#     in2: 18
#   motor_right:
#     in1: 22
#     in2: 23
#   motors_enable: 12
#   servo_turret:
#     signal: 19
#
# @example Initialize GPIO manager
#   gpio_manager = GpioManager.new('config/gpio_pins.yml', logger)
#   left_motor = gpio_manager.left_motor
#   left_motor[:in1].write(1)  # Set left motor IN1 pin HIGH
#
# @see GpioController Uses GpioManager to control motors
class GpioManager
  include Pigpio::Constant

  # @!attribute [r] left_motor
  #   @return [Hash] Left motor pins with keys :in1 and :in2
  #
  # @!attribute [r] right_motor
  #   @return [Hash] Right motor pins with keys :in1 and :in2
  #
  # @!attribute [r] pwm_pins
  #   @return [Hash, nil] PWM pins with :motors key for shared enable, or nil if unavailable
  #
  # @!attribute [r] servo_pin
  #   @return [Pigpio::IF::GPIO, nil] Servo signal pin, or nil if not configured
  attr_reader :left_motor, :right_motor, :pwm_pins, :servo_pin

  # Initializes the GPIO manager and all pins
  #
  # Loads the pin configuration from YAML file and initializes all GPIO pins
  # as outputs. Sets all pins to LOW (safe coast mode) initially.
  #
  # @param config_path [String] Path to GPIO configuration YAML file
  # @param logger [Logger, nil] Logger instance for output (default: stdout)
  #
  # @return [GpioManager] A new GPIO manager instance
  #
  # @raise [Errno::ENOENT] If config file doesn't exist
  # @raise [Psych::SyntaxError] If YAML is malformed
  # @raise [RuntimeError] If pigpio connection fails
  def initialize(config_path = 'config/gpio_pins.yml', logger = nil)
    @logger = logger || Logger.new($stdout)
    @config = YAML.load_file(config_path)
    @cleaned_up = false
    @pi = Pigpio.new

    raise 'Failed to connect to pigpio. Is pigpiod daemon running?' unless @pi.connect

    initialize_pins
    @logger.info 'GPIO pins initialized'
  end

  # Initializes all GPIO pins from configuration
  #
  # Creates pigpio GPIO objects for all motors based on the loaded configuration.
  # Each motor gets two output pins (IN1 and IN2) for controlling direction.
  # After initialization, all pins are reset to LOW.
  #
  # @return [void]
  #
  # @api private
  def initialize_pins
    # Initialize left motor pins
    @left_motor = {
      in1: setup_output_pin(@config['motor_left']['in1']),
      in2: setup_output_pin(@config['motor_left']['in2'])
    }

    # Initialize right motor pins
    @right_motor = {
      in1: setup_output_pin(@config['motor_right']['in1']),
      in2: setup_output_pin(@config['motor_right']['in2'])
    }

    # Initialize PWM pins for wheel motors (optional - graceful degradation)
    @pwm_pins = initialize_pwm_pins

    # Initialize servo pin for turret (optional - graceful degradation)
    @servo_pin = initialize_servo_pin

    # Set all pins to LOW (coast) initially
    reset_all_pins
  end

  # Sets up a GPIO pin as an output
  #
  # @param pin_number [Integer] BCM GPIO pin number
  # @return [Pigpio::IF::GPIO] Configured GPIO object
  #
  # @api private
  def setup_output_pin(pin_number)
    pin = @pi.gpio(pin_number)
    pin.mode = PI_OUTPUT
    pin.pud = PI_PUD_OFF
    pin
  end

  # Initializes shared PWM pin for wheel motor speed control
  #
  # Reads the shared enable pin number from config and creates GPIO object.
  # Both DRV8833 drivers have their EEP pins wired together, so a single
  # PWM signal controls speed for both motors simultaneously.
  # Returns nil if not configured or initialization fails.
  #
  # @return [Hash, nil] PWM pins with :motors key, or nil if unavailable
  #
  # @api private
  def initialize_pwm_pins
    enable_pin = @config['motors_enable']
    return nil unless enable_pin

    pin = setup_output_pin(enable_pin)
    @logger.info "Shared motors PWM initialized on GPIO #{enable_pin}"
    { motors: pin }
  rescue StandardError => e
    @logger.warn "Shared motors PWM initialization failed: #{e.message}"
    nil
  end

  # Initializes servo signal pin for turret control
  #
  # Reads servo pin number from config and creates GPIO object.
  # Returns nil if not configured or initialization fails.
  #
  # @return [Pigpio::IF::GPIO, nil] Servo pin or nil if unavailable
  #
  # @api private
  def initialize_servo_pin
    servo_config = @config['servo_turret']
    return nil unless servo_config

    signal_pin = servo_config['signal']
    return nil unless signal_pin

    pin = setup_output_pin(signal_pin)
    @logger.info "Servo initialized on GPIO #{signal_pin}"
    pin
  rescue StandardError => e
    @logger.warn "Servo initialization failed: #{e.message}"
    nil
  end

  # Resets all GPIO pins to safe state
  #
  # Sets both input pins for wheel motors to LOW (coast mode) where motors
  # can freely spin down. Releases servo by setting pulsewidth to 0.
  # Also resets PWM duty cycles to 0 if PWM pins are available.
  #
  # @return [void]
  def reset_all_pins
    [@left_motor, @right_motor].each do |motor|
      motor[:in1].write(0)
      motor[:in2].write(0)
    end

    # Reset PWM duty cycles if available
    @pwm_pins&.each_value { |pin| pin.pwm.dutycycle = 0 }

    # Release servo (stop PWM signal)
    @servo_pin&.pwm&.servo_pulsewidth = 0

    @logger.debug 'All GPIO pins reset to safe state'
  end

  # Cleans up GPIO resources
  #
  # Resets all pins to LOW and disconnects from pigpio daemon. This should
  # be called before program exit.
  #
  # @return [void]
  def cleanup
    return if @cleaned_up

    @logger.info 'Cleaning up GPIO pins'
    reset_all_pins
    @pi.stop
    @cleaned_up = true
  end

  # Checks if cleanup has been performed
  #
  # @return [Boolean] true if cleanup has been called, false otherwise
  def cleaned_up?
    @cleaned_up
  end

  # Stops all motors by resetting pins
  #
  # Convenience method that delegates to reset_all_pins. Used for emergency
  # stop situations.
  #
  # @return [void]
  def stop_motors
    reset_all_pins
  end
end
