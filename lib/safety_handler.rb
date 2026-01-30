# frozen_string_literal: true

# Handles signal trapping and emergency safety mechanisms
#
# This class provides critical safety features for the robot control system:
# - Graceful shutdown on interrupt signals (SIGINT, SIGTERM)
# - Emergency motor stop before exit
# - GPIO cleanup to prevent pins being left in unsafe states
# - Protection against multiple cleanup attempts
#
# The SafetyHandler traps Unix signals and ensures that motors are stopped
# and GPIO pins are reset even if the program is interrupted. This prevents
# motors from continuing to run if the program crashes or is killed.
#
# Signal handling:
# - SIGINT (Ctrl+C): Triggers graceful shutdown
# - SIGTERM (kill): Triggers graceful shutdown
#
# The handler is automatically set up during application initialization
# and requires no user intervention. It maintains state to prevent duplicate
# cleanup operations.
#
# @example Setup safety handler
#   SafetyHandler.setup(controller, logger)
#   # Now Ctrl+C will safely stop motors and clean up GPIO
#
# @example Emergency shutdown (called automatically)
#   SafetyHandler.emergency_shutdown
#   # Stops motors, cleans GPIO, logs completion
class SafetyHandler
  # Sets up signal trapping and exit handlers
  #
  # Configures the safety system to trap SIGINT and SIGTERM signals,
  # and registers an at_exit handler for cleanup. Should be called once
  # during application initialization.
  #
  # @param controller [ControlInterface] The controller to stop/cleanup on shutdown
  # @param logger [Logger, nil] Logger instance for output (default: stdout)
  #
  # @return [void]
  #
  # @example
  #   controller = GpioController.new(gpio_manager, logger)
  #   SafetyHandler.setup(controller, logger)
  def self.setup(controller, logger = nil)
    @logger = logger || Logger.new($stdout)
    @controller = controller

    # Trap interrupt signals for graceful shutdown
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        @logger.warn "\nReceived #{signal} signal, shutting down safely..."
        emergency_shutdown
        exit(0)
      end
    end

    # Ensure cleanup on exit
    at_exit do
      emergency_shutdown unless @cleaned_up
    end

    @logger.info 'Safety handler configured'
  end

  # Performs emergency shutdown of motors and GPIO
  #
  # Stops all motors and cleans up GPIO pins, ensuring the robot is left
  # in a safe state. Handles errors gracefully and prevents duplicate cleanup.
  # This method is called automatically by signal handlers and at_exit hooks.
  #
  # The method is idempotent - calling it multiple times is safe as it
  # tracks whether cleanup has already been performed.
  #
  # @return [void]
  #
  # @note This method catches all StandardError exceptions to ensure cleanup
  #   attempts don't crash the shutdown process.
  #
  # @example Manual emergency shutdown
  #   SafetyHandler.emergency_shutdown
  def self.emergency_shutdown
    return if @cleaned_up
    return unless @controller && @logger

    begin
      @logger.warn 'Emergency shutdown: stopping motors and cleaning up GPIO'
      @controller.stop_motors
      @controller.cleanup
      @cleaned_up = true
      @logger.info 'Safe shutdown complete'
    rescue StandardError => e
      @logger.error "Error during emergency shutdown: #{e.message}"
    end
  end

  # Validates duration parameter with strict limits
  #
  # Ensures duration is positive and within maximum allowed value.
  # Unlike Robot's validation, this method raises an error if the maximum
  # is exceeded rather than limiting it.
  #
  # @param duration [Integer, nil] Duration in milliseconds
  # @param max_duration [Integer] Maximum allowed duration in milliseconds
  #
  # @return [Integer, nil] Validated duration, or nil if input was nil
  #
  # @raise [ArgumentError] If duration is zero, negative, or exceeds maximum
  #
  # @example Validate duration
  #   SafetyHandler.validate_duration(1000, 5000)
  #   # => 1000
  #
  # @example Duration too long
  #   SafetyHandler.validate_duration(10000, 5000)
  #   # raises ArgumentError: "Duration exceeds maximum of 5000ms"
  def self.validate_duration(duration, max_duration)
    return nil if duration.nil?

    duration = duration.to_i
    raise ArgumentError, 'Duration must be positive' if duration <= 0
    raise ArgumentError, "Duration exceeds maximum of #{max_duration}ms" if duration > max_duration

    duration
  end
end
