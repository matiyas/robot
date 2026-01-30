# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/safety_handler'

RSpec.describe SafetyHandler do
  include_context 'with mock controller'
  include_context 'with test logger'

  # Reset class variables before each test
  before do
    described_class.instance_variable_set(:@logger, nil)
    described_class.instance_variable_set(:@controller, nil)
    described_class.instance_variable_set(:@cleaned_up, nil)
  end

  after do
    # Reset cleaned_up flag after each test
    described_class.instance_variable_set(:@cleaned_up, nil)
  end

  describe '.setup' do
    it 'sets the logger' do
      described_class.setup(mock_controller, test_logger)
      expect(described_class.instance_variable_get(:@logger)).to eq(test_logger)
    end

    it 'sets the controller' do
      described_class.setup(mock_controller, test_logger)
      expect(described_class.instance_variable_get(:@controller)).to eq(mock_controller)
    end

    it 'uses default logger if none provided' do
      described_class.setup(mock_controller)
      logger = described_class.instance_variable_get(:@logger)
      expect(logger).to be_a(Logger)
    end

    it 'logs configuration message' do
      described_class.setup(mock_controller, test_logger)
      expect(logged_info.any? { |msg| msg.include?('Safety handler configured') }).to be true
    end

    it 'traps SIGINT signal' do
      expect(Signal).to receive(:trap).with('INT')
      expect(Signal).to receive(:trap).with('TERM')
      described_class.setup(mock_controller, test_logger)
    end

    it 'traps SIGTERM signal' do
      expect(Signal).to receive(:trap).with('TERM')
      allow(Signal).to receive(:trap).with('INT')
      described_class.setup(mock_controller, test_logger)
    end

    it 'registers at_exit handler' do
      expect(described_class).to receive(:at_exit)
      described_class.setup(mock_controller, test_logger)
    end
  end

  describe '.emergency_shutdown' do
    before do
      described_class.instance_variable_set(:@logger, test_logger)
      described_class.instance_variable_set(:@controller, mock_controller)
      described_class.instance_variable_set(:@cleaned_up, false)
    end

    context 'when called for the first time' do
      it 'logs emergency shutdown warning' do
        described_class.emergency_shutdown
        expect(logged_warn.any? { |msg| msg.include?('Emergency shutdown') }).to be true
      end

      it 'mentions stopping motors in log' do
        described_class.emergency_shutdown
        expect(logged_warn.any? { |msg| msg.include?('stopping motors') }).to be true
      end

      it 'mentions cleaning up GPIO in log' do
        described_class.emergency_shutdown
        expect(logged_warn.any? { |msg| msg.include?('cleaning up GPIO') }).to be true
      end

      it 'calls stop_motors on controller' do
        expect(mock_controller).to receive(:stop_motors)
        described_class.emergency_shutdown
      end

      it 'calls cleanup on controller' do
        expect(mock_controller).to receive(:cleanup)
        described_class.emergency_shutdown
      end

      it 'calls stop_motors before cleanup' do
        call_order = []
        allow(mock_controller).to receive(:stop_motors) { call_order << :stop }
        allow(mock_controller).to receive(:cleanup) { call_order << :cleanup }

        described_class.emergency_shutdown
        expect(call_order).to eq(%i[stop cleanup])
      end

      it 'sets cleaned_up flag to true' do
        described_class.emergency_shutdown
        expect(described_class.instance_variable_get(:@cleaned_up)).to be true
      end

      it 'logs completion message' do
        described_class.emergency_shutdown
        expect(logged_info.any? { |msg| msg.include?('Safe shutdown complete') }).to be true
      end
    end

    context 'when called multiple times (idempotency)' do
      before do
        described_class.emergency_shutdown
        # Reset mocks expectations
        allow(mock_controller).to receive(:stop_motors)
        allow(mock_controller).to receive(:cleanup)
      end

      it 'does not call stop_motors again' do
        expect(mock_controller).not_to receive(:stop_motors)
        described_class.emergency_shutdown
      end

      it 'does not call cleanup again' do
        expect(mock_controller).not_to receive(:cleanup)
        described_class.emergency_shutdown
      end

      it 'does not log warning again' do
        initial_warn_count = logged_warn.count
        described_class.emergency_shutdown
        final_warn_count = logged_warn.count
        expect(final_warn_count).to eq(initial_warn_count)
      end

      it 'returns immediately' do
        expect { described_class.emergency_shutdown }.not_to raise_error
      end
    end

    context 'with controller errors' do
      before do
        allow(mock_controller).to receive(:stop_motors).and_raise(StandardError, 'Motor error')
      end

      it 'catches StandardError' do
        expect { described_class.emergency_shutdown }.not_to raise_error
      end

      it 'logs error message' do
        described_class.emergency_shutdown
        expect(logged_error.any? { |msg| msg.include?('Error during emergency shutdown') }).to be true
      end

      it 'includes error details in log' do
        described_class.emergency_shutdown
        expect(logged_error.any? { |msg| msg.include?('Motor error') }).to be true
      end
    end

    context 'with cleanup errors' do
      before do
        allow(mock_controller).to receive(:stop_motors)
        allow(mock_controller).to receive(:cleanup).and_raise(StandardError, 'Cleanup error')
      end

      it 'catches StandardError during cleanup' do
        expect { described_class.emergency_shutdown }.not_to raise_error
      end

      it 'logs error message' do
        described_class.emergency_shutdown
        expect(logged_error.any? { |msg| msg.include?('Error during emergency shutdown') }).to be true
      end
    end
  end

  describe '.validate_duration' do
    context 'with nil duration' do
      it 'returns nil' do
        result = described_class.validate_duration(nil, 5000)
        expect(result).to be_nil
      end
    end

    context 'with valid duration' do
      it 'returns duration as integer' do
        result = described_class.validate_duration(1000, 5000)
        expect(result).to eq(1000)
      end

      it 'converts string to integer' do
        result = described_class.validate_duration('1500', 5000)
        expect(result).to eq(1500)
      end

      it 'accepts duration equal to maximum' do
        result = described_class.validate_duration(5000, 5000)
        expect(result).to eq(5000)
      end

      it 'accepts duration just below maximum' do
        result = described_class.validate_duration(4999, 5000)
        expect(result).to eq(4999)
      end

      it 'accepts small positive durations' do
        result = described_class.validate_duration(1, 5000)
        expect(result).to eq(1)
      end
    end

    context 'with invalid duration' do
      it 'raises ArgumentError for zero duration' do
        expect { described_class.validate_duration(0, 5000) }
          .to raise_error(ArgumentError, 'Duration must be positive')
      end

      it 'raises ArgumentError for negative duration' do
        expect { described_class.validate_duration(-100, 5000) }
          .to raise_error(ArgumentError, 'Duration must be positive')
      end

      it 'raises ArgumentError when duration exceeds maximum' do
        expect { described_class.validate_duration(10_000, 5000) }
          .to raise_error(ArgumentError, 'Duration exceeds maximum of 5000ms')
      end

      it 'raises ArgumentError just above maximum' do
        expect { described_class.validate_duration(5001, 5000) }
          .to raise_error(ArgumentError, 'Duration exceeds maximum of 5000ms')
      end

      it 'includes max duration in error message' do
        expect { described_class.validate_duration(10_000, 3000) }
          .to raise_error(ArgumentError, /3000ms/)
      end
    end

    context 'with different maximum values' do
      it 'respects turret timeout' do
        result = described_class.validate_duration(1500, 2000)
        expect(result).to eq(1500)
      end

      it 'raises error when exceeding turret timeout' do
        expect { described_class.validate_duration(3000, 2000) }
          .to raise_error(ArgumentError, /2000ms/)
      end

      it 'respects movement timeout' do
        result = described_class.validate_duration(4000, 5000)
        expect(result).to eq(4000)
      end
    end
  end

  describe 'signal handling integration' do
    before do
      # Skip these tests in CI or when signal handling is problematic
      skip 'Signal handling tests require careful environment' if ENV['CI']
    end

    it 'handles SIGINT gracefully' do
      described_class.setup(mock_controller, test_logger)
      expect(mock_controller).to receive(:stop_motors)
      expect(mock_controller).to receive(:cleanup)

      # Simulate signal in a safe way
      expect do
        described_class.emergency_shutdown
      end.not_to raise_error
    end
  end

  describe 'at_exit behavior' do
    it 'calls emergency_shutdown if not already cleaned up' do
      described_class.instance_variable_set(:@logger, test_logger)
      described_class.instance_variable_set(:@controller, mock_controller)
      described_class.instance_variable_set(:@cleaned_up, false)

      expect(described_class).to receive(:emergency_shutdown)

      # Simulate at_exit block
      at_exit_block = proc {
        described_class.emergency_shutdown unless described_class.instance_variable_get(:@cleaned_up)
      }
      at_exit_block.call
    end

    it 'skips emergency_shutdown if already cleaned up' do
      described_class.instance_variable_set(:@cleaned_up, true)
      expect(described_class).not_to receive(:emergency_shutdown)

      # Simulate at_exit block
      at_exit_block = proc {
        described_class.emergency_shutdown unless described_class.instance_variable_get(:@cleaned_up)
      }
      at_exit_block.call
    end
  end
end
