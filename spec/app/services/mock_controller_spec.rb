# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/mock_controller'

RSpec.describe MockController do
  subject(:controller) { described_class.new(test_logger) }

  include_context 'with test logger'

  it_behaves_like 'a controller implementing ControlInterface'

  describe '#initialize' do
    it 'logs initialization' do
      described_class.new(test_logger)
      expect(logged_info.any? { |msg| msg.include?('MockController initialized') }).to be true
    end

    it 'mentions no GPIO in initialization log' do
      described_class.new(test_logger)
      expect(logged_info.any? { |msg| msg.include?('no GPIO') }).to be true
    end

    it 'uses default logger if none provided' do
      controller_with_default = described_class.new
      expect(controller_with_default.instance_variable_get(:@logger)).to be_a(Logger)
    end
  end

  describe '#move_forward' do
    it_behaves_like 'a movement method', :move_forward

    context 'without duration' do
      it 'logs FORWARD action' do
        controller.move_forward
        expect(logged_messages).to include(a_string_matching(/FORWARD/))
      end

      it 'logs continuous movement' do
        controller.move_forward
        expect(logged_messages).to include(a_string_matching(/continuous/))
      end

      it 'does not create a thread' do
        expect(Thread).not_to receive(:new)
        controller.move_forward
      end
    end

    context 'with duration' do
      it 'logs FORWARD action with duration' do
        controller.move_forward(duration: 1000)
        expect(logged_messages).to include(a_string_matching(/FORWARD.*1000ms/))
      end

      it 'creates a thread to simulate movement' do
        expect(Thread).to receive(:new).and_call_original
        controller.move_forward(duration: 100)
      end

      it 'logs completion after duration' do
        controller.move_forward(duration: 50)
        sleep(0.1)
        expect(logged_messages).to include(a_string_matching(/Movement completed/))
      end
    end
  end

  describe '#move_backward' do
    it_behaves_like 'a movement method', :move_backward

    it 'logs BACKWARD action' do
      controller.move_backward
      expect(logged_messages).to include(a_string_matching(/BACKWARD/))
    end

    it 'logs duration when provided' do
      controller.move_backward(duration: 500)
      expect(logged_messages).to include(a_string_matching(/BACKWARD.*500ms/))
    end

    it 'simulates timing when duration provided' do
      controller.move_backward(duration: 50)
      sleep(0.1)
      expect(logged_messages).to include(match(/Movement completed/))
    end
  end

  describe '#turn_left' do
    it_behaves_like 'a movement method', :turn_left

    it 'logs TURN LEFT action' do
      controller.turn_left
      expect(logged_messages).to include(a_string_matching(/TURN LEFT/))
    end

    it 'logs duration when provided' do
      controller.turn_left(duration: 750)
      expect(logged_messages).to include(a_string_matching(/TURN LEFT.*750ms/))
    end

    it 'simulates timing when duration provided' do
      controller.turn_left(duration: 50)
      sleep(0.1)
      expect(logged_messages).to include(match(/Movement completed/))
    end
  end

  describe '#turn_right' do
    it_behaves_like 'a movement method', :turn_right

    it 'logs TURN RIGHT action' do
      controller.turn_right
      expect(logged_messages).to include(a_string_matching(/TURN RIGHT/))
    end

    it 'logs duration when provided' do
      controller.turn_right(duration: 250)
      expect(logged_messages).to include(a_string_matching(/TURN RIGHT.*250ms/))
    end

    it 'simulates timing when duration provided' do
      controller.turn_right(duration: 50)
      sleep(0.1)
      expect(logged_messages).to include(match(/Movement completed/))
    end
  end

  describe '#turret_left' do
    it_behaves_like 'a movement method', :turret_left

    it 'logs TURRET LEFT action' do
      controller.turret_left
      expect(logged_messages).to include(a_string_matching(/TURRET LEFT/))
    end

    it 'logs duration when provided' do
      controller.turret_left(duration: 300)
      expect(logged_messages).to include(a_string_matching(/TURRET LEFT.*300ms/))
    end

    it 'simulates timing when duration provided' do
      controller.turret_left(duration: 50)
      sleep(0.1)
      expect(logged_messages).to include(match(/Movement completed/))
    end
  end

  describe '#turret_right' do
    it_behaves_like 'a movement method', :turret_right

    it 'logs TURRET RIGHT action' do
      controller.turret_right
      expect(logged_messages).to include(a_string_matching(/TURRET RIGHT/))
    end

    it 'logs duration when provided' do
      controller.turret_right(duration: 400)
      expect(logged_messages).to include(a_string_matching(/TURRET RIGHT.*400ms/))
    end

    it 'simulates timing when duration provided' do
      controller.turret_right(duration: 50)
      sleep(0.1)
      expect(logged_messages).to include(match(/Movement completed/))
    end
  end

  describe '#stop_motors' do
    it 'logs STOP ALL MOTORS' do
      controller.stop_motors
      expect(logged_messages).to include(a_string_matching(/STOP ALL MOTORS/))
    end

    it 'does not raise an error' do
      expect { controller.stop_motors }.not_to raise_error
    end

    it 'can be called multiple times' do
      expect { controller.stop_motors }.not_to raise_error
      expect { controller.stop_motors }.not_to raise_error
      expect { controller.stop_motors }.not_to raise_error
    end
  end

  describe '#cleanup' do
    it 'logs cleanup message' do
      controller.cleanup
      expect(logged_messages).to include(a_string_matching(/MockController cleanup/))
    end

    it 'mentions no-op in cleanup log' do
      controller.cleanup
      expect(logged_messages).to include(a_string_matching(/no-op/))
    end

    it 'does not raise an error' do
      expect { controller.cleanup }.not_to raise_error
    end

    it 'can be called multiple times safely (idempotent)' do
      expect { controller.cleanup }.not_to raise_error
      expect { controller.cleanup }.not_to raise_error
      expect { controller.cleanup }.not_to raise_error
    end
  end

  describe 'thread safety and timing' do
    it 'can handle multiple concurrent movements' do
      controller.move_forward(duration: 100)
      controller.turn_left(duration: 100)
      controller.turret_right(duration: 100)
      sleep(0.15)
      completion_logs = logged_messages.count { |line| line.include?('Movement completed') }
      expect(completion_logs).to eq(3)
    end
  end

  describe 'no GPIO operations' do
    it 'does not require PiPiper module' do
      expect { controller.move_forward }.not_to raise_error
    end

    it 'works without GPIO hardware' do
      expect { controller.move_backward(duration: 10) }.not_to raise_error
      expect { controller.turn_left(duration: 10) }.not_to raise_error
      expect { controller.turn_right(duration: 10) }.not_to raise_error
    end
  end
end
