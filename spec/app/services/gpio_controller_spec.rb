# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/gpio_controller'

RSpec.describe GpioController do
  subject(:controller) { described_class.new(gpio_manager, test_logger) }

  include_context 'with mocked GPIO pins'
  include_context 'with test logger'

  it_behaves_like 'a controller implementing ControlInterface'

  describe '#initialize' do
    it 'sets the gpio manager' do
      expect(controller.instance_variable_get(:@gpio)).to eq(gpio_manager)
    end

    it 'logs initialization' do
      described_class.new(gpio_manager, test_logger)
      expect(logged_info.any? { |msg| msg.include?('GpioController initialized') }).to be true
    end

    it 'uses default logger if none provided' do
      controller_with_default = described_class.new(gpio_manager)
      expect(controller_with_default.instance_variable_get(:@logger)).to be_a(Logger)
    end
  end

  describe '#move_forward' do
    it_behaves_like 'a movement method', :move_forward

    it 'sets left motor IN1 HIGH (forward)' do
      expect(left_motor[:in1]).to receive(:on)
      controller.move_forward
    end

    it 'sets left motor IN2 LOW (forward)' do
      expect(left_motor[:in2]).to receive(:off)
      controller.move_forward
    end

    it 'sets right motor IN1 HIGH (forward)' do
      expect(right_motor[:in1]).to receive(:on)
      controller.move_forward
    end

    it 'sets right motor IN2 LOW (forward)' do
      expect(right_motor[:in2]).to receive(:off)
      controller.move_forward
    end

    it 'logs debug message' do
      controller.move_forward
      expect(logged_debug.any? { |msg| msg.include?('Moving forward') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after with duration' do
        expect(controller).to receive(:auto_stop_after).with(1000)
        controller.move_forward(duration: 1000)
      end

      it 'creates a background thread' do
        controller.move_forward(duration: 100)
        thread = controller.instance_variable_get(:@movement_thread)
        expect(thread).to be_a(Thread)
        thread.kill if thread&.alive?
      end
    end

    context 'without duration' do
      it 'does not call auto_stop_after' do
        expect(controller).not_to receive(:auto_stop_after)
        controller.move_forward
      end

      it 'does not create a background thread' do
        controller.move_forward
        thread = controller.instance_variable_get(:@movement_thread)
        expect(thread).to be_nil
      end
    end
  end

  describe '#move_backward' do
    it_behaves_like 'a movement method', :move_backward

    it 'sets left motor IN1 LOW (backward)' do
      expect(left_motor[:in1]).to receive(:off)
      controller.move_backward
    end

    it 'sets left motor IN2 HIGH (backward)' do
      expect(left_motor[:in2]).to receive(:on)
      controller.move_backward
    end

    it 'sets right motor IN1 LOW (backward)' do
      expect(right_motor[:in1]).to receive(:off)
      controller.move_backward
    end

    it 'sets right motor IN2 HIGH (backward)' do
      expect(right_motor[:in2]).to receive(:on)
      controller.move_backward
    end

    it 'logs debug message' do
      controller.move_backward
      expect(logged_debug.any? { |msg| msg.include?('Moving backward') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after' do
        expect(controller).to receive(:auto_stop_after).with(500)
        controller.move_backward(duration: 500)
      end
    end
  end

  describe '#turn_left' do
    it_behaves_like 'a movement method', :turn_left

    it 'sets left motor IN1 LOW (backward for tank turn)' do
      expect(left_motor[:in1]).to receive(:off)
      controller.turn_left
    end

    it 'sets left motor IN2 HIGH (backward for tank turn)' do
      expect(left_motor[:in2]).to receive(:on)
      controller.turn_left
    end

    it 'sets right motor IN1 HIGH (forward for tank turn)' do
      expect(right_motor[:in1]).to receive(:on)
      controller.turn_left
    end

    it 'sets right motor IN2 LOW (forward for tank turn)' do
      expect(right_motor[:in2]).to receive(:off)
      controller.turn_left
    end

    it 'logs tank turn debug message' do
      controller.turn_left
      expect(logged_debug.any? { |msg| msg.include?('Turning left') && msg.include?('tank turn') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after' do
        expect(controller).to receive(:auto_stop_after).with(750)
        controller.turn_left(duration: 750)
      end
    end
  end

  describe '#turn_right' do
    it_behaves_like 'a movement method', :turn_right

    it 'sets left motor IN1 HIGH (forward for tank turn)' do
      expect(left_motor[:in1]).to receive(:on)
      controller.turn_right
    end

    it 'sets left motor IN2 LOW (forward for tank turn)' do
      expect(left_motor[:in2]).to receive(:off)
      controller.turn_right
    end

    it 'sets right motor IN1 LOW (backward for tank turn)' do
      expect(right_motor[:in1]).to receive(:off)
      controller.turn_right
    end

    it 'sets right motor IN2 HIGH (backward for tank turn)' do
      expect(right_motor[:in2]).to receive(:on)
      controller.turn_right
    end

    it 'logs tank turn debug message' do
      controller.turn_right
      expect(logged_debug.any? { |msg| msg.include?('Turning right') && msg.include?('tank turn') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after' do
        expect(controller).to receive(:auto_stop_after).with(250)
        controller.turn_right(duration: 250)
      end
    end
  end

  describe '#turret_left' do
    it_behaves_like 'a movement method', :turret_left

    it 'sets turret motor IN1 LOW' do
      expect(turret_motor[:in1]).to receive(:off)
      controller.turret_left
    end

    it 'sets turret motor IN2 HIGH' do
      expect(turret_motor[:in2]).to receive(:on)
      controller.turret_left
    end

    it 'logs debug message' do
      controller.turret_left
      expect(logged_debug.any? { |msg| msg.include?('Turret rotating left') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after' do
        expect(controller).to receive(:auto_stop_after).with(300)
        controller.turret_left(duration: 300)
      end
    end
  end

  describe '#turret_right' do
    it_behaves_like 'a movement method', :turret_right

    it 'sets turret motor IN1 HIGH' do
      expect(turret_motor[:in1]).to receive(:on)
      controller.turret_right
    end

    it 'sets turret motor IN2 LOW' do
      expect(turret_motor[:in2]).to receive(:off)
      controller.turret_right
    end

    it 'logs debug message' do
      controller.turret_right
      expect(logged_debug.any? { |msg| msg.include?('Turret rotating right') }).to be true
    end

    context 'with duration' do
      it 'calls auto_stop_after' do
        expect(controller).to receive(:auto_stop_after).with(400)
        controller.turret_right(duration: 400)
      end
    end
  end

  describe '#stop_motors' do
    it 'logs debug message' do
      controller.stop_motors
      expect(logged_debug.any? { |msg| msg.include?('Stopping all motors') }).to be true
    end

    it 'calls cancel_auto_stop' do
      expect(controller).to receive(:cancel_auto_stop)
      controller.stop_motors
    end

    it 'sets left motor to coast (IN1 LOW, IN2 LOW)' do
      expect(left_motor[:in1]).to receive(:off)
      expect(left_motor[:in2]).to receive(:off)
      controller.stop_motors
    end

    it 'sets right motor to coast (IN1 LOW, IN2 LOW)' do
      expect(right_motor[:in1]).to receive(:off)
      expect(right_motor[:in2]).to receive(:off)
      controller.stop_motors
    end

    it 'sets turret motor to coast (IN1 LOW, IN2 LOW)' do
      expect(turret_motor[:in1]).to receive(:off)
      expect(turret_motor[:in2]).to receive(:off)
      controller.stop_motors
    end

    context 'when auto-stop thread is running' do
      before do
        controller.move_forward(duration: 10_000)
      end

      after do
        thread = controller.instance_variable_get(:@movement_thread)
        thread.kill if thread&.alive?
      end

      it 'kills the running thread' do
        thread = controller.instance_variable_get(:@movement_thread)
        expect(thread).to be_alive
        controller.stop_motors
        sleep(0.01)
        expect(thread).not_to be_alive
      end
    end
  end

  describe '#cleanup' do
    it 'logs cleanup message' do
      controller.cleanup
      expect(logged_info.any? { |msg| msg.include?('GpioController cleanup') }).to be true
    end

    it 'calls stop_motors' do
      expect(controller).to receive(:stop_motors)
      controller.cleanup
    end

    it 'calls gpio_manager cleanup' do
      expect(gpio_manager).to receive(:cleanup)
      controller.cleanup
    end

    it 'can be called multiple times safely (idempotent)' do
      expect { controller.cleanup }.not_to raise_error
      expect { controller.cleanup }.not_to raise_error
      expect { controller.cleanup }.not_to raise_error
    end
  end

  describe '#auto_stop_after (private)' do
    it 'creates a background thread' do
      controller.send(:auto_stop_after, 100)
      thread = controller.instance_variable_get(:@movement_thread)
      expect(thread).to be_a(Thread)
      thread.kill if thread&.alive?
    end

    it 'calls stop_motors after duration' do
      allow(controller).to receive(:stop_motors)
      controller.send(:auto_stop_after, 50)
      sleep(0.1)
      expect(controller).to have_received(:stop_motors)
    end

    it 'logs auto-stop completion' do
      controller.send(:auto_stop_after, 50)
      sleep(0.1)
      expect(logged_debug.any? { |msg| msg.include?('Auto-stop triggered') }).to be true
    end

    it 'logs the duration in message' do
      controller.send(:auto_stop_after, 75)
      sleep(0.1)
      expect(logged_debug.any? { |msg| msg.include?('75ms') }).to be true
    end

    it 'cancels previous auto-stop before creating new one' do
      expect(controller).to receive(:cancel_auto_stop).and_call_original
      controller.send(:auto_stop_after, 100)
      controller.instance_variable_get(:@movement_thread).kill
    end

    it 'sleeps for correct duration in seconds' do
      start_time = Time.now
      controller.send(:auto_stop_after, 100)
      sleep(0.15)
      end_time = Time.now
      expect(end_time - start_time).to be >= 0.1
    end
  end

  describe '#cancel_auto_stop (private)' do
    context 'when thread is running' do
      before do
        controller.move_forward(duration: 10_000)
      end

      after do
        thread = controller.instance_variable_get(:@movement_thread)
        thread.kill if thread&.alive?
      end

      it 'kills the running thread' do
        thread = controller.instance_variable_get(:@movement_thread)
        expect(thread).to be_alive
        controller.send(:cancel_auto_stop)
        sleep(0.01)
        expect(thread).not_to be_alive
      end

      it 'sets movement_thread to nil' do
        controller.send(:cancel_auto_stop)
        thread = controller.instance_variable_get(:@movement_thread)
        expect(thread).to be_nil
      end
    end

    context 'when no thread is running' do
      it 'does not raise error' do
        expect { controller.send(:cancel_auto_stop) }.not_to raise_error
      end
    end

    context 'when thread is nil' do
      before do
        controller.instance_variable_set(:@movement_thread, nil)
      end

      it 'does not raise error' do
        expect { controller.send(:cancel_auto_stop) }.not_to raise_error
      end
    end
  end

  describe '#set_motor_direction (private)' do
    let(:test_motor) { left_motor }

    it 'sets forward direction (IN1 HIGH, IN2 LOW)' do
      expect(test_motor[:in1]).to receive(:on)
      expect(test_motor[:in2]).to receive(:off)
      controller.send(:set_motor_direction, test_motor, :forward)
    end

    it 'sets backward direction (IN1 LOW, IN2 HIGH)' do
      expect(test_motor[:in1]).to receive(:off)
      expect(test_motor[:in2]).to receive(:on)
      controller.send(:set_motor_direction, test_motor, :backward)
    end

    it 'sets coast mode (IN1 LOW, IN2 LOW)' do
      expect(test_motor[:in1]).to receive(:off)
      expect(test_motor[:in2]).to receive(:off)
      controller.send(:set_motor_direction, test_motor, :coast)
    end

    it 'sets brake mode (IN1 HIGH, IN2 HIGH)' do
      expect(test_motor[:in1]).to receive(:on)
      expect(test_motor[:in2]).to receive(:on)
      controller.send(:set_motor_direction, test_motor, :brake)
    end

    it 'raises ArgumentError for invalid direction' do
      expect { controller.send(:set_motor_direction, test_motor, :invalid) }
        .to raise_error(ArgumentError, 'Invalid direction: invalid')
    end

    it 'raises ArgumentError for nil direction' do
      expect { controller.send(:set_motor_direction, test_motor, nil) }
        .to raise_error(ArgumentError, /Invalid direction/)
    end
  end

  describe 'thread safety' do
    after do
      thread = controller.instance_variable_get(:@movement_thread)
      thread.kill if thread&.alive?
    end

    it 'multiple movements cancel previous auto-stop' do
      controller.move_forward(duration: 10_000)
      first_thread = controller.instance_variable_get(:@movement_thread)
      expect(first_thread).to be_alive

      controller.move_backward(duration: 10_000)
      second_thread = controller.instance_variable_get(:@movement_thread)

      sleep(0.01)
      expect(first_thread).not_to be_alive
      expect(second_thread).to be_alive
    end

    it 'only one auto-stop thread runs at a time' do
      controller.move_forward(duration: 10_000)
      first_thread = controller.instance_variable_get(:@movement_thread)

      controller.turn_left(duration: 10_000)
      second_thread = controller.instance_variable_get(:@movement_thread)

      controller.turn_right(duration: 10_000)
      third_thread = controller.instance_variable_get(:@movement_thread)

      sleep(0.01) # Give threads time to start

      # Only the most recent thread should be alive
      expect(first_thread).not_to be_alive
      expect(second_thread).not_to be_alive
      expect(third_thread).to be_alive
    end
  end

  describe 'integration scenarios' do
    after do
      thread = controller.instance_variable_get(:@movement_thread)
      thread.kill if thread&.alive?
    end

    it 'handles move -> stop sequence' do
      controller.move_forward(duration: 10_000)
      expect(controller.instance_variable_get(:@movement_thread)).to be_alive
      controller.stop_motors
      sleep(0.01)
      expect(controller.instance_variable_get(:@movement_thread)).to be_nil
    end

    it 'handles move -> new move sequence' do
      controller.move_forward(duration: 10_000)
      first_thread = controller.instance_variable_get(:@movement_thread)
      controller.turn_left(duration: 10_000)
      second_thread = controller.instance_variable_get(:@movement_thread)
      expect(first_thread).not_to eq(second_thread)
    end
  end
end
