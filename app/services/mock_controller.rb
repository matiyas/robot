# frozen_string_literal: true

require_relative 'control_interface'

# Mock controller for development and testing
#
# Provides a simulated robot controller that implements the ControlInterface
# without requiring actual GPIO hardware. Perfect for:
# - Development on non-Raspberry Pi systems (Mac, Linux, Windows)
# - Testing API endpoints without hardware
# - Debugging control logic
# - CI/CD pipeline testing
#
# Instead of controlling GPIO pins, this controller logs all actions to
# the logger. It simulates the timing behavior of real movements using background threads.
#
# The MockController is automatically used when gpio_enabled is false in
# the settings configuration.
#
# @example Initialize mock controller
#   controller = MockController.new(logger)
#   controller = MockController.new(logger, pwm_enabled: true)  # with PWM simulation
#
# @example Move forward (logs instead of controlling hardware)
#   controller.move_forward(duration: 1000)
#   # Logs: "FORWARD for 1000ms"
#   # After 1 second logs: "Movement completed"
#
# @see ControlInterface Abstract base class
# @see GpioController Real hardware implementation
class MockController < ControlInterface
  # Initializes the mock controller
  #
  # @param logger [Logger, nil] Logger instance for output (default: stdout)
  # @param pwm_enabled [Boolean] Whether to simulate PWM soft-start logging
  #
  # @return [MockController] A new mock controller instance
  def initialize(logger = nil, pwm_enabled: false) # rubocop:disable Lint/MissingSuper
    @logger = logger || Logger.new($stdout)
    @pwm_enabled = pwm_enabled
    pwm_status = @pwm_enabled ? ', PWM simulation enabled' : nil
    @logger.info "MockController initialized (no GPIO#{pwm_status})"
  end

  # Simulates moving forward
  #
  # Logs the forward action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def move_forward(duration: nil)
    log_action('FORWARD', duration)
    log_pwm_ramp(%i[left right])
    simulate_movement(duration) if duration
  end

  # Simulates moving backward
  #
  # Logs the backward action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def move_backward(duration: nil)
    log_action('BACKWARD', duration)
    log_pwm_ramp(%i[left right])
    simulate_movement(duration) if duration
  end

  # Simulates turning left
  #
  # Logs the turn left action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turn_left(duration: nil)
    log_action('TURN LEFT', duration)
    log_pwm_ramp(%i[left right])
    simulate_movement(duration) if duration
  end

  # Simulates turning right
  #
  # Logs the turn right action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turn_right(duration: nil)
    log_action('TURN RIGHT', duration)
    log_pwm_ramp(%i[left right])
    simulate_movement(duration) if duration
  end

  # Simulates turret rotation to the left
  #
  # Logs the turret left action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turret_left(duration: nil)
    log_action('TURRET LEFT', duration)
    log_pwm_ramp(%i[turret])
    simulate_movement(duration) if duration
  end

  # Simulates turret rotation to the right
  #
  # Logs the turret right action and simulates movement timing if duration is specified.
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  def turret_right(duration: nil)
    log_action('TURRET RIGHT', duration)
    log_pwm_ramp(%i[turret])
    simulate_movement(duration) if duration
  end

  # Simulates stopping all motors
  #
  # Logs the stop action.
  #
  # @return [void]
  def stop_motors
    @logger.info 'STOP ALL MOTORS'
  end

  # Mock cleanup (no-op)
  #
  # Logs cleanup but performs no actual operations since there are no
  # hardware resources to release.
  #
  # @return [void]
  def cleanup
    @logger.info 'MockController cleanup (no-op)'
  end

  private

  # Logs an action with formatted output
  #
  # Creates a formatted log message showing the action and duration.
  #
  # @param action [String] The action being performed (e.g., 'FORWARD', 'TURRET LEFT')
  # @param duration [Integer, nil] Duration in milliseconds, or nil for continuous
  #
  # @return [void]
  #
  # @api private
  def log_action(action, duration)
    duration_str = duration ? " for #{duration}ms" : ' (continuous)'
    @logger.info "#{action}#{duration_str}"
  end

  # Simulates movement timing with a background thread
  #
  # Creates a thread that sleeps for the specified duration and then logs
  # completion. This mimics the timing behavior of real motor control.
  #
  # @param duration [Integer] Duration in milliseconds
  #
  # @return [Thread] The background thread (not joined, runs independently)
  #
  # @api private
  def simulate_movement(duration)
    Thread.new do
      sleep(duration / 1000.0)
      @logger.info 'Movement completed'
    end
  end

  # Logs PWM ramp simulation for specified motors
  #
  # Only logs when PWM simulation is enabled. Used to verify PWM
  # integration in development mode.
  #
  # @param motors [Array<Symbol>] Motor identifiers (:left, :right, :turret)
  #
  # @return [void]
  #
  # @api private
  def log_pwm_ramp(motors)
    return unless @pwm_enabled

    motors.each do |motor|
      @logger.debug "PWM #{motor}: simulating ramp-up"
    end
  end
end
