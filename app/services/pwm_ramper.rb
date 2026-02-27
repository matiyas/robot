# frozen_string_literal: true

# Handles smooth PWM duty cycle ramping for motor soft-start
#
# This class provides linear ramp-up of PWM duty cycle over a configurable
# duration to prevent inrush current spikes that can reset the Raspberry Pi.
#
# The ramper runs asynchronously in a background thread, allowing motor
# control to return immediately while the ramp executes. Only one ramp
# can be active per motor at a time - starting a new ramp cancels any
# existing ramp for that motor.
#
# @example Basic usage
#   ramper = PwmRamper.new(pwm_pins, settings, logger)
#   ramper.ramp_up(:left)   # Ramps left motor to full power
#   ramper.ramp_up(:right)  # Ramps right motor independently
#   ramper.stop(:left)      # Immediately stops left motor
#
# @see GpioController Uses PwmRamper for soft-start
class PwmRamper
  # Default step interval for duty cycle updates (milliseconds)
  STEP_INTERVAL_MS = 20

  # Default maximum duty cycle (pigpio range)
  DEFAULT_MAX_DUTY_CYCLE = 255

  # Default ramp duration in milliseconds
  DEFAULT_RAMP_DURATION = 500

  # Initializes the PWM ramper
  #
  # @param pwm_pins [Hash] PWM pin objects keyed by motor symbol (:left, :right, :turret)
  # @param settings [Hash] Configuration with pwm_ramp_duration key
  # @param logger [Logger, nil] Logger instance for debugging
  def initialize(pwm_pins, settings, logger = nil)
    @pwm_pins = pwm_pins || {}
    @settings = settings || {}
    @logger = logger || Logger.new($stdout)
    @ramp_threads = {}
    @mutex = Mutex.new
  end

  # Ramps motor PWM duty cycle from 0 to max over configured duration
  #
  # Cancels any existing ramp for this motor before starting a new one.
  # The ramp runs in a background thread and returns immediately.
  #
  # @param motor [Symbol] Motor identifier (:left, :right, :turret)
  # @return [void]
  def ramp_up(motor)
    cancel_ramp(motor)

    pwm_pin = @pwm_pins[motor]
    return unless pwm_pin

    @mutex.synchronize do
      @ramp_threads[motor] = create_ramp_thread(motor, pwm_pin)
    end
  end

  # Immediately stops motor PWM and cancels any active ramp
  #
  # @param motor [Symbol] Motor identifier (:left, :right, :turret)
  # @return [void]
  def stop(motor)
    cancel_ramp(motor)
    set_duty_cycle(motor, 0)
  end

  # Stops all motors and cancels all ramps
  #
  # @return [void]
  def stop_all
    %i[left right turret].each { |motor| stop(motor) }
  end

  # Sets immediate duty cycle without ramping
  #
  # @param motor [Symbol] Motor identifier (:left, :right, :turret)
  # @param duty_cycle [Integer] Duty cycle value (0 to 255)
  # @return [void]
  def set_duty_cycle(motor, duty_cycle)
    pwm_pin = @pwm_pins[motor]
    return unless pwm_pin

    pwm_pin.pwm(duty_cycle)
    @logger.debug "PWM #{motor}: duty cycle set to #{duty_cycle}"
  end

  # Checks if PWM is available for a motor
  #
  # @param motor [Symbol] Motor identifier (:left, :right, :turret)
  # @return [Boolean] true if PWM pin exists for this motor
  def available?(motor)
    @pwm_pins.key?(motor) && !@pwm_pins[motor].nil?
  end

  private

  # Cancels any active ramp thread for the specified motor
  #
  # @param motor [Symbol] Motor identifier
  # @return [void]
  # @api private
  def cancel_ramp(motor)
    @mutex.synchronize do
      thread = @ramp_threads[motor]
      if thread&.alive?
        thread.kill
        thread.join(0.1)
        @logger.debug "PWM #{motor}: ramp cancelled"
      end
      @ramp_threads[motor] = nil
    end
  end

  # Creates a background thread to execute the ramp
  #
  # @param motor [Symbol] Motor identifier
  # @param pwm_pin [Object] pigpio PWM pin object
  # @return [Thread] The ramp execution thread
  # @api private
  def create_ramp_thread(motor, pwm_pin)
    Thread.new do
      execute_ramp(motor, pwm_pin)
    end
  end

  # Executes the duty cycle ramp from 0 to max
  #
  # @param motor [Symbol] Motor identifier
  # @param pwm_pin [Object] pigpio PWM pin object
  # @return [void]
  # @api private
  def execute_ramp(motor, pwm_pin)
    duration_ms = @settings['pwm_ramp_duration'] || DEFAULT_RAMP_DURATION
    max_duty = DEFAULT_MAX_DUTY_CYCLE
    steps = (duration_ms / STEP_INTERVAL_MS).to_i
    steps = 1 if steps < 1

    duty_increment = max_duty.to_f / steps

    @logger.debug "PWM #{motor}: ramping to #{max_duty} over #{duration_ms}ms (#{steps} steps)"

    steps.times do |step|
      current_duty = ((step + 1) * duty_increment).to_i
      current_duty = [current_duty, max_duty].min
      pwm_pin.pwm(current_duty)
      sleep(STEP_INTERVAL_MS / 1000.0)
    end

    @logger.debug "PWM #{motor}: ramp complete"
  end
end
