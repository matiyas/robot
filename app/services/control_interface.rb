# frozen_string_literal: true

# Abstract base class for robot control implementations
#
# Defines the contract that all controller implementations must follow.
# This enables the Strategy pattern, allowing different control implementations
# to be swapped at runtime without changing the Robot class.
#
# Implementations must provide methods for:
# - Movement control (forward, backward, left, right)
# - Turret control (left, right)
# - Emergency stop
# - Resource cleanup
#
# Current implementations:
# - {GpioController}: Real hardware control via Raspberry Pi GPIO
# - {MockController}: Development/testing mock without hardware
#
# Future possible implementations:
# - GamePadController: Control via USB gamepad/joystick
# - RemoteController: Control via network commands
# - AutonomousController: Autonomous navigation with sensors
#
# @abstract Subclass and override all methods to implement a controller
#
# @example Implementing a custom controller
#   class MyController < ControlInterface
#     def move_forward(duration: nil)
#       # Implementation here
#     end
#     # ... implement all other methods
#   end
#
# @see GpioController
# @see MockController
class ControlInterface
  # Moves the robot forward
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def move_forward(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #move_forward"
  end

  # Moves the robot backward
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def move_backward(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #move_backward"
  end

  # Turns the robot left using tank turning
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def turn_left(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #turn_left"
  end

  # Turns the robot right using tank turning
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def turn_right(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #turn_right"
  end

  # Rotates the turret left
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def turret_left(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #turret_left"
  end

  # Rotates the turret right
  #
  # @abstract Subclasses must implement this method
  #
  # @param duration [Integer, nil] Duration in milliseconds (nil for continuous)
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def turret_right(duration: nil)
    raise NotImplementedError, "#{self.class} must implement #turret_right"
  end

  # Emergency stop for all motors
  #
  # Should immediately stop all motor movement and set motors to safe state.
  #
  # @abstract Subclasses must implement this method
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def stop_motors
    raise NotImplementedError, "#{self.class} must implement #stop_motors"
  end

  # Cleanup resources and reset hardware state
  #
  # Should release all resources, reset GPIO pins to safe state,
  # and perform any necessary shutdown procedures.
  #
  # @abstract Subclasses must implement this method
  #
  # @return [void]
  #
  # @raise [NotImplementedError] If not implemented by subclass
  def cleanup
    raise NotImplementedError, "#{self.class} must implement #cleanup"
  end
end
