# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/gpio_manager'

RSpec.describe GpioManager do
  subject(:gpio_manager) { described_class.new(config_path, test_logger) }

  include_context 'with test logger'

  let(:config_path) { 'spec/fixtures/gpio_pins.yml' }
  let(:gpio_config) do
    {
      'motor_left' => { 'in1' => 17, 'in2' => 18 },
      'motor_right' => { 'in1' => 22, 'in2' => 23 },
      'motor_turret' => { 'in1' => 27, 'in2' => 24 }
    }
  end

  # Mock PiPiper::Pin class
  let(:mock_pin_class) { class_double(PiPiper::Pin) }
  let(:left_in1_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }
  let(:left_in2_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }
  let(:right_in1_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }
  let(:right_in2_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }
  let(:turret_in1_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }
  let(:turret_in2_pin) { instance_double(PiPiper::Pin, on: nil, off: nil) }

  before do
    # Mock YAML loading
    allow(YAML).to receive(:load_file).with(config_path).and_return(gpio_config)

    # Mock Pin.new calls - need to stub the constant
    stub_const('PiPiper::Pin', mock_pin_class)

    # Mock pin creation
    allow(mock_pin_class).to receive(:new).with(pin: 17, direction: :out).and_return(left_in1_pin)
    allow(mock_pin_class).to receive(:new).with(pin: 18, direction: :out).and_return(left_in2_pin)
    allow(mock_pin_class).to receive(:new).with(pin: 22, direction: :out).and_return(right_in1_pin)
    allow(mock_pin_class).to receive(:new).with(pin: 23, direction: :out).and_return(right_in2_pin)
    allow(mock_pin_class).to receive(:new).with(pin: 27, direction: :out).and_return(turret_in1_pin)
    allow(mock_pin_class).to receive(:new).with(pin: 24, direction: :out).and_return(turret_in2_pin)
  end

  describe '#initialize' do
    it 'loads configuration from YAML file' do
      expect(YAML).to receive(:load_file).with(config_path).and_return(gpio_config)
      described_class.new(config_path, test_logger)
    end

    it 'creates left motor IN1 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 17, direction: :out).and_return(left_in1_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates left motor IN2 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 18, direction: :out).and_return(left_in2_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates right motor IN1 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 22, direction: :out).and_return(right_in1_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates right motor IN2 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 23, direction: :out).and_return(right_in2_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates turret motor IN1 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 27, direction: :out).and_return(turret_in1_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates turret motor IN2 pin with correct number' do
      expect(mock_pin_class).to receive(:new).with(pin: 24, direction: :out).and_return(turret_in2_pin)
      described_class.new(config_path, test_logger)
    end

    it 'creates all pins as output pins' do
      expect(mock_pin_class).to receive(:new).exactly(6).times.with(hash_including(direction: :out))
      described_class.new(config_path, test_logger)
    end

    it 'calls reset_all_pins to set initial state' do
      described_class.new(config_path, test_logger)
      # Verify all pins were set to off during initialization
      expect(left_in1_pin).to have_received(:off)
      expect(left_in2_pin).to have_received(:off)
      expect(right_in1_pin).to have_received(:off)
      expect(right_in2_pin).to have_received(:off)
      expect(turret_in1_pin).to have_received(:off)
      expect(turret_in2_pin).to have_received(:off)
    end

    it 'logs initialization' do
      described_class.new(config_path, test_logger)
      expect(logged_info.any? { |msg| msg.include?('GPIO pins initialized') }).to be true
    end

    it 'uses default logger if none provided' do
      manager = described_class.new(config_path)
      expect(manager.instance_variable_get(:@logger)).to be_a(Logger)
    end

    it 'initializes cleaned_up flag as false' do
      manager = described_class.new(config_path, test_logger)
      expect(manager.cleaned_up?).to be false
    end
  end

  describe '#left_motor' do
    it 'returns hash with :in1 and :in2 keys' do
      expect(gpio_manager.left_motor).to be_a(Hash)
      expect(gpio_manager.left_motor.keys).to contain_exactly(:in1, :in2)
    end

    it 'returns left motor IN1 pin' do
      expect(gpio_manager.left_motor[:in1]).to eq(left_in1_pin)
    end

    it 'returns left motor IN2 pin' do
      expect(gpio_manager.left_motor[:in2]).to eq(left_in2_pin)
    end
  end

  describe '#right_motor' do
    it 'returns hash with :in1 and :in2 keys' do
      expect(gpio_manager.right_motor).to be_a(Hash)
      expect(gpio_manager.right_motor.keys).to contain_exactly(:in1, :in2)
    end

    it 'returns right motor IN1 pin' do
      expect(gpio_manager.right_motor[:in1]).to eq(right_in1_pin)
    end

    it 'returns right motor IN2 pin' do
      expect(gpio_manager.right_motor[:in2]).to eq(right_in2_pin)
    end
  end

  describe '#turret_motor' do
    it 'returns hash with :in1 and :in2 keys' do
      expect(gpio_manager.turret_motor).to be_a(Hash)
      expect(gpio_manager.turret_motor.keys).to contain_exactly(:in1, :in2)
    end

    it 'returns turret motor IN1 pin' do
      expect(gpio_manager.turret_motor[:in1]).to eq(turret_in1_pin)
    end

    it 'returns turret motor IN2 pin' do
      expect(gpio_manager.turret_motor[:in2]).to eq(turret_in2_pin)
    end
  end

  describe '#reset_all_pins' do
    before do
      # Clear previous off calls from initialization - just reset the mock expectations
      allow(left_in1_pin).to receive(:off)
      allow(left_in2_pin).to receive(:off)
      allow(right_in1_pin).to receive(:off)
      allow(right_in2_pin).to receive(:off)
      allow(turret_in1_pin).to receive(:off)
      allow(turret_in2_pin).to receive(:off)
    end

    it 'sets all left motor pins to LOW' do
      expect(left_in1_pin).to receive(:off)
      expect(left_in2_pin).to receive(:off)
      gpio_manager.reset_all_pins
    end

    it 'sets all right motor pins to LOW' do
      expect(right_in1_pin).to receive(:off)
      expect(right_in2_pin).to receive(:off)
      gpio_manager.reset_all_pins
    end

    it 'sets all turret motor pins to LOW' do
      expect(turret_in1_pin).to receive(:off)
      expect(turret_in2_pin).to receive(:off)
      gpio_manager.reset_all_pins
    end

    it 'logs debug message' do
      gpio_manager.reset_all_pins
      expect(logged_debug.any? { |msg| msg.include?('All GPIO pins reset to LOW') }).to be true
    end

    it 'can be called multiple times safely' do
      expect { gpio_manager.reset_all_pins }.not_to raise_error
      expect { gpio_manager.reset_all_pins }.not_to raise_error
      expect { gpio_manager.reset_all_pins }.not_to raise_error
    end
  end

  describe '#stop_motors' do
    it 'calls reset_all_pins' do
      expect(gpio_manager).to receive(:reset_all_pins)
      gpio_manager.stop_motors
    end

    it 'sets all pins to LOW' do
      # Allow pins to receive off messages
      allow(left_in1_pin).to receive(:off)
      allow(left_in2_pin).to receive(:off)
      allow(right_in1_pin).to receive(:off)
      allow(right_in2_pin).to receive(:off)
      allow(turret_in1_pin).to receive(:off)
      allow(turret_in2_pin).to receive(:off)

      expect(left_in1_pin).to receive(:off)
      expect(left_in2_pin).to receive(:off)
      expect(right_in1_pin).to receive(:off)
      expect(right_in2_pin).to receive(:off)
      expect(turret_in1_pin).to receive(:off)
      expect(turret_in2_pin).to receive(:off)
      gpio_manager.stop_motors
    end
  end

  describe '#cleanup' do
    it 'logs cleanup message' do
      gpio_manager.cleanup
      expect(logged_info.any? { |msg| msg.include?('Cleaning up GPIO pins') }).to be true
    end

    it 'calls reset_all_pins' do
      expect(gpio_manager).to receive(:reset_all_pins).and_call_original
      gpio_manager.cleanup
    end

    it 'sets cleaned_up flag to true' do
      gpio_manager.cleanup
      expect(gpio_manager.cleaned_up?).to be true
    end

    it 'is idempotent (can be called multiple times)' do
      gpio_manager.cleanup
      expect(gpio_manager).not_to receive(:reset_all_pins)
      gpio_manager.cleanup
    end

    it 'does not reset pins on second call' do
      gpio_manager.cleanup

      # Reset mocks to verify second call doesn't reset pins
      allow(left_in1_pin).to receive(:off)
      allow(left_in2_pin).to receive(:off)

      # Second cleanup should not call off
      expect(left_in1_pin).not_to receive(:off)
      expect(left_in2_pin).not_to receive(:off)
      gpio_manager.cleanup
    end

    it 'does not log on second call' do
      gpio_manager.cleanup
      initial_log_count = logged_info.count { |msg| msg.include?('Cleaning up') }

      gpio_manager.cleanup
      final_log_count = logged_info.count { |msg| msg.include?('Cleaning up') }

      expect(final_log_count).to eq(initial_log_count)
    end
  end

  describe '#cleaned_up?' do
    it 'returns false initially' do
      expect(gpio_manager.cleaned_up?).to be false
    end

    it 'returns true after cleanup' do
      gpio_manager.cleanup
      expect(gpio_manager.cleaned_up?).to be true
    end

    it 'remains true after multiple cleanup calls' do
      gpio_manager.cleanup
      gpio_manager.cleanup
      gpio_manager.cleanup
      expect(gpio_manager.cleaned_up?).to be true
    end
  end

  describe 'configuration file handling' do
    context 'with missing config file' do
      let(:missing_path) { 'nonexistent/path/gpio_pins.yml' }

      it 'raises error when file does not exist' do
        allow(YAML).to receive(:load_file).with(missing_path).and_raise(Errno::ENOENT)
        expect { described_class.new(missing_path, test_logger) }
          .to raise_error(Errno::ENOENT)
      end
    end

    context 'with malformed YAML' do
      it 'raises error when YAML is invalid' do
        # Create a proper Psych::SyntaxError
        error = Psych::SyntaxError.new(config_path, 1, 1, 0, 'syntax error', 'test context')
        allow(YAML).to receive(:load_file).with(config_path).and_raise(error)
        expect { described_class.new(config_path, test_logger) }
          .to raise_error(Psych::SyntaxError)
      end
    end
  end
end
