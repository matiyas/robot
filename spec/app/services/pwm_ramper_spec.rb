# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/pwm_ramper'

RSpec.describe PwmRamper do
  subject(:ramper) { described_class.new(pwm_pins, settings, test_logger) }

  include_context 'with test logger'

  let(:motors_pwm_obj) { instance_double(Pigpio::PWM) }

  let(:motors_pwm) do
    pin = instance_double(Pigpio::UserGPIO)
    allow(pin).to receive(:pwm).and_return(motors_pwm_obj)
    pin
  end

  let(:pwm_pins) { { motors: motors_pwm } }
  let(:settings) do
    {
      'pwm_ramp_duration' => 100,
      'pwm_frequency' => 1000
    }
  end

  before do
    allow(motors_pwm_obj).to receive(:dutycycle=)
  end

  describe '#initialize' do
    it 'creates a new instance with pwm_pins and settings' do
      expect { ramper }.not_to raise_error
    end

    it 'handles nil pwm_pins gracefully' do
      expect { described_class.new(nil, settings, test_logger) }.not_to raise_error
    end

    it 'handles nil settings gracefully' do
      expect { described_class.new(pwm_pins, nil, test_logger) }.not_to raise_error
    end
  end

  describe '#ramp_up' do
    it 'sets duty cycle incrementally for motors' do
      expect(motors_pwm_obj).to receive(:dutycycle=).at_least(:once)
      ramper.ramp_up(:motors)
      sleep(0.15)
    end

    it 'reaches max duty cycle at end of ramp' do
      duty_cycles = []
      allow(motors_pwm_obj).to receive(:dutycycle=) { |dc| duty_cycles << dc }

      ramper.ramp_up(:motors)
      sleep(0.15)

      expect(duty_cycles.last).to eq(255)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.ramp_up(:nonexistent) }.not_to raise_error
    end

    it 'cancels existing ramp before starting new one' do
      expect(motors_pwm_obj).to receive(:dutycycle=).at_least(:once)

      ramper.ramp_up(:motors)
      sleep(0.05)
      ramper.ramp_up(:motors)
      sleep(0.15)
    end

    it 'logs ramp progress' do
      ramper.ramp_up(:motors)
      sleep(0.15)

      expect(logged_debug.any? { |msg| msg.include?('PWM motors: ramping') }).to be true
      expect(logged_debug.any? { |msg| msg.include?('ramp complete') }).to be true
    end
  end

  describe '#stop' do
    it 'sets duty cycle to 0 immediately' do
      expect(motors_pwm_obj).to receive(:dutycycle=).with(0)
      ramper.stop(:motors)
    end

    it 'cancels any active ramp' do
      ramper.ramp_up(:motors)
      sleep(0.02)
      expect(motors_pwm_obj).to receive(:dutycycle=).with(0)
      ramper.stop(:motors)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.stop(:nonexistent) }.not_to raise_error
    end
  end

  describe '#stop_all' do
    it 'stops motors' do
      expect(motors_pwm_obj).to receive(:dutycycle=).with(0)

      ramper.stop_all
    end
  end

  describe '#set_duty_cycle' do
    it 'sets immediate duty cycle without ramping' do
      expect(motors_pwm_obj).to receive(:dutycycle=).with(128)
      ramper.set_duty_cycle(:motors, 128)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.set_duty_cycle(:nonexistent, 128) }.not_to raise_error
    end

    it 'logs duty cycle changes' do
      ramper.set_duty_cycle(:motors, 128)
      expect(logged_debug.any? { |msg| msg.include?('duty cycle set to 128') }).to be true
    end
  end

  describe '#available?' do
    it 'returns true for configured motors' do
      expect(ramper.available?(:motors)).to be true
    end

    it 'returns false for unconfigured motors' do
      expect(ramper.available?(:nonexistent)).to be false
    end

    context 'with nil pwm_pins' do
      let(:pwm_pins) { nil }

      it 'returns false for all motors' do
        ramper_without_pins = described_class.new(nil, settings, test_logger)
        expect(ramper_without_pins.available?(:motors)).to be false
      end
    end
  end

  describe 'thread safety' do
    it 'handles concurrent ramp and stop calls' do
      expect(motors_pwm_obj).to receive(:dutycycle=).at_least(:once)

      ramper.ramp_up(:motors)

      threads = []
      threads << Thread.new { ramper.stop(:motors) }

      threads.each(&:join)
    end
  end

  describe 'with default settings' do
    let(:settings) { {} }

    it 'uses default ramp duration of 500ms' do
      duty_cycles = []
      allow(motors_pwm_obj).to receive(:dutycycle=) { |dc| duty_cycles << dc }

      ramper.ramp_up(:motors)
      sleep(0.1)
      ramper.stop(:motors)

      expect(duty_cycles).not_to be_empty
    end
  end
end
