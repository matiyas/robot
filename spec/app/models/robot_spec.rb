# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/models/robot'

RSpec.describe Robot do
  subject(:robot) { described_class.new(mock_controller, test_settings, test_logger) }

  include_context 'with mock controller'
  include_context 'with test logger'
  include_context 'with test settings'

  describe '#initialize' do
    it 'sets the controller' do
      expect(robot.controller).to eq(mock_controller)
    end

    it 'uses default logger if none provided' do
      robot_with_default = described_class.new(mock_controller, test_settings)
      expect(robot_with_default.instance_variable_get(:@logger)).to be_a(Logger)
    end
  end

  describe '#move' do
    context 'with forward direction' do
      it 'calls move_forward on the controller' do
        expect(mock_controller).to receive(:move_forward).with(duration: nil)
        robot.move('forward')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:move_forward).with(duration: 1000)
        robot.move('forward', duration: 1000)
      end

      it 'returns action hash with direction and duration' do
        allow(mock_controller).to receive(:move_forward)
        result = robot.move('forward', duration: 1000)
        expect(result).to eq({ action: 'forward', duration: 1000 })
      end

      it_behaves_like 'duration validation', :move, 'forward'
    end

    context 'with backward direction' do
      it 'calls move_backward on the controller' do
        expect(mock_controller).to receive(:move_backward).with(duration: nil)
        robot.move('backward')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:move_backward).with(duration: 1000)
        robot.move('backward', duration: 1000)
      end

      it 'returns action hash' do
        allow(mock_controller).to receive(:move_backward)
        result = robot.move('backward', duration: 1500)
        expect(result).to eq({ action: 'backward', duration: 1500 })
      end

      it_behaves_like 'duration validation', :move, 'backward'
    end

    context 'with left direction' do
      it 'calls turn_left on the controller (tank turn)' do
        expect(mock_controller).to receive(:turn_left).with(duration: nil)
        robot.move('left')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:turn_left).with(duration: 500)
        robot.move('left', duration: 500)
      end

      it 'returns action hash' do
        allow(mock_controller).to receive(:turn_left)
        result = robot.move('left', duration: 500)
        expect(result).to eq({ action: 'left', duration: 500 })
      end

      it_behaves_like 'duration validation', :move, 'left'
    end

    context 'with right direction' do
      it 'calls turn_right on the controller (tank turn)' do
        expect(mock_controller).to receive(:turn_right).with(duration: nil)
        robot.move('right')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:turn_right).with(duration: 750)
        robot.move('right', duration: 750)
      end

      it 'returns action hash' do
        allow(mock_controller).to receive(:turn_right)
        result = robot.move('right', duration: 750)
        expect(result).to eq({ action: 'right', duration: 750 })
      end

      it_behaves_like 'duration validation', :move, 'right'
    end

    context 'with invalid direction' do
      it 'raises ArgumentError for unknown direction' do
        expect { robot.move('sideways') }
          .to raise_error(ArgumentError, 'Invalid direction: sideways')
      end

      it 'raises ArgumentError for nil direction' do
        expect { robot.move(nil) }
          .to raise_error(ArgumentError, /Invalid direction/)
      end

      it 'raises ArgumentError for empty string' do
        expect { robot.move('') }
          .to raise_error(ArgumentError, /Invalid direction/)
      end

      it 'raises ArgumentError for numeric direction' do
        expect { robot.move(123) }
          .to raise_error(ArgumentError, /Invalid direction/)
      end

      it 'does not call controller for invalid direction' do
        expect(mock_controller).not_to receive(:move_forward)
        expect(mock_controller).not_to receive(:move_backward)
        expect(mock_controller).not_to receive(:turn_left)
        expect(mock_controller).not_to receive(:turn_right)
        expect { robot.move('invalid') }.to raise_error(ArgumentError)
      end
    end

    context 'when limiting duration' do
      let(:test_settings) do
        {
          'movement_timeout' => 3000,
          'turret_timeout' => 2000,
          'gpio_enabled' => false,
          'camera_url' => 'http://test.local:8081'
        }
      end

      it 'limits duration to movement_timeout when exceeded' do
        allow(mock_controller).to receive(:move_forward)
        result = robot.move('forward', duration: 10_000)
        expect(result[:duration]).to eq(3000)
      end

      it 'logs warning when limiting duration' do
        allow(mock_controller).to receive(:move_forward)
        robot.move('forward', duration: 10_000)
        expect(logged_warn.any? { |msg| msg.include?('exceeds max') }).to be true
      end

      it 'does not limit duration when within limit' do
        allow(mock_controller).to receive(:move_forward)
        result = robot.move('forward', duration: 2000)
        expect(result[:duration]).to eq(2000)
      end

      it 'does not log warning when duration within limit' do
        allow(mock_controller).to receive(:move_forward)
        robot.move('forward', duration: 2000)
        expect(logged_warn).to be_empty
      end

      it 'does not limit nil duration' do
        allow(mock_controller).to receive(:move_forward)
        result = robot.move('forward', duration: nil)
        expect(result[:duration]).to be_nil
      end
    end
  end

  describe '#turret' do
    context 'with left direction' do
      it 'calls turret_left on the controller' do
        expect(mock_controller).to receive(:turret_left).with(duration: nil)
        robot.turret('left')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:turret_left).with(duration: 500)
        robot.turret('left', duration: 500)
      end

      it 'returns action hash with turret_left' do
        allow(mock_controller).to receive(:turret_left)
        result = robot.turret('left', duration: 500)
        expect(result).to eq({ action: 'turret_left', duration: 500 })
      end

      it_behaves_like 'duration validation', :turret, 'left'
    end

    context 'with right direction' do
      it 'calls turret_right on the controller' do
        expect(mock_controller).to receive(:turret_right).with(duration: nil)
        robot.turret('right')
      end

      it 'passes duration to controller' do
        expect(mock_controller).to receive(:turret_right).with(duration: 750)
        robot.turret('right', duration: 750)
      end

      it 'returns action hash with turret_right' do
        allow(mock_controller).to receive(:turret_right)
        result = robot.turret('right', duration: 750)
        expect(result).to eq({ action: 'turret_right', duration: 750 })
      end

      it_behaves_like 'duration validation', :turret, 'right'
    end

    context 'with invalid direction' do
      it 'raises ArgumentError for forward direction' do
        expect { robot.turret('forward') }
          .to raise_error(ArgumentError, 'Invalid turret direction: forward')
      end

      it 'raises ArgumentError for unknown direction' do
        expect { robot.turret('up') }
          .to raise_error(ArgumentError, /Invalid turret direction/)
      end

      it 'raises ArgumentError for nil direction' do
        expect { robot.turret(nil) }
          .to raise_error(ArgumentError, /Invalid turret direction/)
      end

      it 'does not call controller for invalid direction' do
        expect(mock_controller).not_to receive(:turret_left)
        expect(mock_controller).not_to receive(:turret_right)
        expect { robot.turret('invalid') }.to raise_error(ArgumentError)
      end
    end

    context 'when limiting duration' do
      let(:test_settings) do
        {
          'movement_timeout' => 5000,
          'turret_timeout' => 1500,
          'gpio_enabled' => false,
          'camera_url' => 'http://test.local:8081'
        }
      end

      it 'limits duration to turret_timeout when exceeded' do
        allow(mock_controller).to receive(:turret_left)
        result = robot.turret('left', duration: 5000)
        expect(result[:duration]).to eq(1500)
      end

      it 'logs warning when limiting duration' do
        allow(mock_controller).to receive(:turret_left)
        robot.turret('left', duration: 5000)
        expect(logged_warn.any? { |msg| msg.include?('exceeds max') }).to be true
      end

      it 'does not limit duration when within limit' do
        allow(mock_controller).to receive(:turret_right)
        result = robot.turret('right', duration: 1000)
        expect(result[:duration]).to eq(1000)
      end
    end
  end

  describe '#stop' do
    it 'calls stop_motors on the controller' do
      expect(mock_controller).to receive(:stop_motors)
      robot.stop
    end

    it 'returns action hash with stop_all' do
      allow(mock_controller).to receive(:stop_motors)
      result = robot.stop
      expect(result).to eq({ action: 'stop_all' })
    end
  end

  describe '#status' do
    it 'returns connected: true' do
      result = robot.status
      expect(result[:connected]).to be true
    end

    it 'returns gpio_enabled from settings' do
      result = robot.status
      expect(result[:gpio_enabled]).to eq(test_settings['gpio_enabled'])
    end

    it 'returns camera_url from settings' do
      result = robot.status
      expect(result[:camera_url]).to eq(test_settings['camera_url'])
    end

    context 'with gpio enabled' do
      let(:test_settings) do
        {
          'movement_timeout' => 5000,
          'turret_timeout' => 2000,
          'gpio_enabled' => true,
          'camera_url' => 'http://raspberrypi.local:8081'
        }
      end

      it 'reflects gpio_enabled as true' do
        result = robot.status
        expect(result[:gpio_enabled]).to be true
      end

      it 'reflects correct camera_url' do
        result = robot.status
        expect(result[:camera_url]).to eq('http://raspberrypi.local:8081')
      end
    end
  end
end
