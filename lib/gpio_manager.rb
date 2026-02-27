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
# Each motor uses two GPIO pins (IN1 and IN2) connected to a DRV8833
# H-bridge driver. The manager groups these pins into motor hashes for
# easy access by the GpioController.
#
# Configuration file format (config/gpio_pins.yml):
#   motor_left:
#     in1: 17
#     in2: 18
#   motor_right:
#     in1: 22
#     in2: 23
#   motor_turret:
#     in1: 27
#     in2: 24
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
  # @!attribute [r] turret_motor
  #   @return [Hash] Turret motor pins with keys :in1 and :in2
  #
  # @!attribute [r] pwm_pins
  #   @return [Hash, nil] PWM pins keyed by motor symbol, or nil if PWM unavailable
  attr_reader :left_motor, :right_motor, :turret_motor, :pwm_pins

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

    # Initialize turret motor pins
    @turret_motor = {
      in1: setup_output_pin(@config['motor_turret']['in1']),
      in2: setup_output_pin(@config['motor_turret']['in2'])
    }

    # Initialize PWM pins (optional - graceful degradation if not present)
    @pwm_pins = initialize_pwm_pins

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

  # Initializes PWM pins for motor speed control
  #
  # Reads enable pin numbers from config and creates GPIO objects for PWM.
  # Returns nil if no enable pins are configured or initialization fails.
  # This provides backward compatibility when PWM pins are not connected.
  #
  # @return [Hash, nil] PWM pins keyed by motor symbol, or nil if unavailable
  #
  # @api private
  def initialize_pwm_pins
    pins = {}
    { left: 'motor_left', right: 'motor_right', turret: 'motor_turret' }.each do |motor_sym, config_key|
      pin = setup_pwm_pin(motor_sym, config_key)
      pins[motor_sym] = pin if pin
    end
    pins.empty? ? nil : pins
  end

  # Sets up a single PWM pin for a motor
  #
  # @param motor_sym [Symbol] Motor identifier
  # @param config_key [String] Configuration key for the motor
  # @return [Pigpio::IF::GPIO, nil] Configured GPIO object or nil if not available
  #
  # @api private
  def setup_pwm_pin(motor_sym, config_key)
    enable_pin = @config.dig(config_key, 'enable')
    return nil unless enable_pin

    pin = setup_output_pin(enable_pin)
    @logger.debug "PWM initialized on GPIO #{enable_pin} for #{motor_sym} motor"
    pin
  rescue StandardError => e
    @logger.warn "PWM initialization failed for #{motor_sym} motor: #{e.message}"
    nil
  end

  # Resets all GPIO pins to LOW (coast mode)
  #
  # Sets both input pins for all motors to LOW, putting them in coast mode
  # where motors can freely spin down. Also resets PWM duty cycles to 0
  # if PWM pins are available. This is the safe default state.
  #
  # @return [void]
  def reset_all_pins
    [@left_motor, @right_motor, @turret_motor].each do |motor|
      motor[:in1].write(0)
      motor[:in2].write(0)
    end

    # Reset PWM duty cycles if available
    @pwm_pins&.each_value { |pin| pin.pwm(0) }

    @logger.debug 'All GPIO pins reset to LOW'
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
