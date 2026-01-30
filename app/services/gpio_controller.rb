# frozen_string_literal: true

require_relative 'control_interface'
require 'pi_piper'

# GPIO controller for DRV8833 dual H-bridge motor drivers
#
# This class provides hardware control for a robot tank using Raspberry Pi
# GPIO pins and DRV8833 motor driver ICs. It controls three independent motors:
# left wheel, right wheel, and camera turret.
#
# The DRV8833 uses two input pins (IN1, IN2) per motor with the following
# truth table:
#
#   IN1  | IN2  | Function
#   -----|------|----------
#   LOW  | LOW  | Coast (motor off, freewheeling)
#   HIGH | LOW  | Forward
#   LOW  | HIGH | Backward
#   HIGH | HIGH | Brake (motor actively stopped)
#
# This implementation uses coast mode for stopping to reduce mechanical stress.
#
# Features:
# - Tank turning (differential drive) for precise rotation
# - Auto-stop timer for safety
# - Thread-safe motor control
# - Proper GPIO cleanup on shutdown
#
# @example Initialize controller
#   gpio_manager = GpioManager.new('config/gpio_pins.yml', logger)
#   controller = GpioController.new(gpio_manager, logger)
#
# @example Move forward for 1 second
#   controller.move_forward(duration: 1000)
#   # Motors run for 1 second, then automatically stop
#
# @see ControlInterface Abstract base class
# @see GpioManager GPIO pin initialization and lifecycle
class GpioController < ControlInterface
  include PiPiper

  # Initializes the GPIO controller
  #
  # @param gpio_manager [GpioManager] Initialized GPIO manager with configured pins
  # @param logger [Logger, nil] Logger instance for debugging (default: stdout)
  #
  # @return [GpioController] A new GPIO controller instance
  def initialize(gpio_manager, logger = nil) # rubocop:disable Lint/MissingSuper
    @gpio = gpio_manager
    @logger = logger || Logger.new($stdout)
    @movement_thread = nil
    @logger.info 'GpioController initialized'
  end

  # Moves both motors forward
  #
  # Sets both wheel motors to forward direction. If duration is specified,
  # motors will automatically stop after that time.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def move_forward(duration: nil)
    @logger.debug 'Moving forward'
    set_motor_direction(@gpio.left_motor, :forward)
    set_motor_direction(@gpio.right_motor, :forward)
    auto_stop_after(duration) if duration
  end

  # Moves both motors backward
  #
  # Sets both wheel motors to backward direction. If duration is specified,
  # motors will automatically stop after that time.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def move_backward(duration: nil)
    @logger.debug 'Moving backward'
    set_motor_direction(@gpio.left_motor, :backward)
    set_motor_direction(@gpio.right_motor, :backward)
    auto_stop_after(duration) if duration
  end

  # Performs a tank turn to the left
  #
  # Rotates the robot in place by setting left motor backward and right motor
  # forward. This differential drive technique allows zero-radius turning.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turn_left(duration: nil)
    @logger.debug 'Turning left (tank turn)'
    # Tank turn: left motor backward, right motor forward
    set_motor_direction(@gpio.left_motor, :backward)
    set_motor_direction(@gpio.right_motor, :forward)
    auto_stop_after(duration) if duration
  end

  # Performs a tank turn to the right
  #
  # Rotates the robot in place by setting left motor forward and right motor
  # backward. This differential drive technique allows zero-radius turning.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turn_right(duration: nil)
    @logger.debug 'Turning right (tank turn)'
    # Tank turn: left motor forward, right motor backward
    set_motor_direction(@gpio.left_motor, :forward)
    set_motor_direction(@gpio.right_motor, :backward)
    auto_stop_after(duration) if duration
  end

  # Rotates the turret motor to the left
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turret_left(duration: nil)
    @logger.debug 'Turret rotating left'
    set_motor_direction(@gpio.turret_motor, :backward)
    auto_stop_after(duration) if duration
  end

  # Rotates the turret motor to the right
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turret_right(duration: nil)
    @logger.debug 'Turret rotating right'
    set_motor_direction(@gpio.turret_motor, :forward)
    auto_stop_after(duration) if duration
  end

  # Stops all motors immediately
  #
  # Cancels any pending auto-stop timer and sets all motors to coast mode
  # (both pins LOW), allowing them to freely spin down.
  #
  # @return [void]
  def stop_motors
    @logger.debug 'Stopping all motors'
    # Only cancel auto-stop if we're not being called from within the movement thread
    cancel_auto_stop unless Thread.current == @movement_thread
    set_motor_direction(@gpio.left_motor, :coast)
    set_motor_direction(@gpio.right_motor, :coast)
    set_motor_direction(@gpio.turret_motor, :coast)
  end

  # Cleans up GPIO resources
  #
  # Stops all motors and delegates cleanup to the GPIO manager, which
  # resets all pins to safe state.
  #
  # @return [void]
  def cleanup
    @logger.info 'GpioController cleanup'
    stop_motors
    @gpio.cleanup
  end

  private

  # Sets motor direction using DRV8833 truth table
  #
  # Controls a motor by setting the appropriate logic levels on its two
  # input pins according to the DRV8833 truth table.
  #
  # Direction mappings:
  # - :forward  -> IN1=HIGH, IN2=LOW  (motor spins forward)
  # - :backward -> IN1=LOW,  IN2=HIGH (motor spins backward)
  # - :coast    -> IN1=LOW,  IN2=LOW  (motor freewheels)
  # - :brake    -> IN1=HIGH, IN2=HIGH (motor actively brakes)
  #
  # @param motor [Hash] Motor hash with :in1 and :in2 pin objects
  # @param direction [Symbol] Motor direction (:forward, :backward, :coast, :brake)
  #
  # @return [void]
  #
  # @raise [ArgumentError] If direction is not recognized
  #
  # @api private
  def set_motor_direction(motor, direction)
    case direction
    when :forward
      motor[:in1].on
      motor[:in2].off
    when :backward
      motor[:in1].off
      motor[:in2].on
    when :coast
      motor[:in1].off
      motor[:in2].off
    when :brake
      motor[:in1].on
      motor[:in2].on
    else
      raise ArgumentError, "Invalid direction: #{direction}"
    end
  end

  # Schedules automatic motor stop after specified duration
  #
  # Creates a background thread that sleeps for the specified duration
  # and then calls stop_motors. Cancels any existing auto-stop timer first.
  #
  # This is a safety feature to prevent motors from running indefinitely
  # if the stop command is not received.
  #
  # @param duration_ms [Integer] Duration in milliseconds
  #
  # @return [void]
  #
  # @api private
  def auto_stop_after(duration_ms)
    cancel_auto_stop
    @movement_thread =
      Thread.new do
        sleep(duration_ms / 1000.0)
        stop_motors
        @logger.debug "Auto-stop triggered after #{duration_ms}ms"
        @movement_thread = nil
      end
  end

  # Cancels the current auto-stop timer if one exists
  #
  # Kills the background thread running the auto-stop timer, preventing
  # motors from being stopped automatically. Called when a new movement
  # command is issued or when stop_motors is called explicitly.
  #
  # @return [void]
  #
  # @api private
  def cancel_auto_stop
    return unless @movement_thread&.alive?

    @movement_thread.kill
    @movement_thread = nil
  end
end
