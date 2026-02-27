# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/pwm_ramper'

RSpec.describe PwmRamper do
  subject(:ramper) { described_class.new(pwm_pins, settings, test_logger) }

  include_context 'with test logger'

  let(:left_pwm) { instance_double(Pigpio::IF::GPIO, pwm: nil) }
  let(:right_pwm) { instance_double(Pigpio::IF::GPIO, pwm: nil) }
  let(:turret_pwm) { instance_double(Pigpio::IF::GPIO, pwm: nil) }
  let(:pwm_pins) { { left: left_pwm, right: right_pwm, turret: turret_pwm } }
  let(:settings) do
    {
      'pwm_ramp_duration' => 100,
      'pwm_frequency' => 1000
    }
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
    it 'sets duty cycle incrementally for left motor' do
      expect(left_pwm).to receive(:pwm).at_least(:once)
      ramper.ramp_up(:left)
      sleep(0.15)
    end

    it 'sets duty cycle incrementally for right motor' do
      expect(right_pwm).to receive(:pwm).at_least(:once)
      ramper.ramp_up(:right)
      sleep(0.15)
    end

    it 'sets duty cycle incrementally for turret motor' do
      expect(turret_pwm).to receive(:pwm).at_least(:once)
      ramper.ramp_up(:turret)
      sleep(0.15)
    end

    it 'reaches max duty cycle at end of ramp' do
      duty_cycles = []
      allow(left_pwm).to receive(:pwm) { |dc| duty_cycles << dc }

      ramper.ramp_up(:left)
      sleep(0.15)

      expect(duty_cycles.last).to eq(255)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.ramp_up(:nonexistent) }.not_to raise_error
    end

    it 'cancels existing ramp before starting new one' do
      expect(left_pwm).to receive(:pwm).at_least(:once)

      ramper.ramp_up(:left)
      sleep(0.05)
      ramper.ramp_up(:left)
      sleep(0.15)
    end

    it 'logs ramp progress' do
      ramper.ramp_up(:left)
      sleep(0.15)

      expect(logged_debug.any? { |msg| msg.include?('PWM left: ramping') }).to be true
      expect(logged_debug.any? { |msg| msg.include?('ramp complete') }).to be true
    end
  end

  describe '#stop' do
    it 'sets duty cycle to 0 immediately' do
      expect(left_pwm).to receive(:pwm).with(0)
      ramper.stop(:left)
    end

    it 'cancels any active ramp' do
      ramper.ramp_up(:left)
      sleep(0.02)
      expect(left_pwm).to receive(:pwm).with(0)
      ramper.stop(:left)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.stop(:nonexistent) }.not_to raise_error
    end
  end

  describe '#stop_all' do
    it 'stops all motors' do
      expect(left_pwm).to receive(:pwm).with(0)
      expect(right_pwm).to receive(:pwm).with(0)
      expect(turret_pwm).to receive(:pwm).with(0)

      ramper.stop_all
    end
  end

  describe '#set_duty_cycle' do
    it 'sets immediate duty cycle without ramping' do
      expect(left_pwm).to receive(:pwm).with(128)
      ramper.set_duty_cycle(:left, 128)
    end

    it 'handles missing motor gracefully' do
      expect { ramper.set_duty_cycle(:nonexistent, 128) }.not_to raise_error
    end

    it 'logs duty cycle changes' do
      ramper.set_duty_cycle(:left, 128)
      expect(logged_debug.any? { |msg| msg.include?('duty cycle set to 128') }).to be true
    end
  end

  describe '#available?' do
    it 'returns true for configured motors' do
      expect(ramper.available?(:left)).to be true
      expect(ramper.available?(:right)).to be true
      expect(ramper.available?(:turret)).to be true
    end

    it 'returns false for unconfigured motors' do
      expect(ramper.available?(:nonexistent)).to be false
    end

    context 'with partial pwm_pins' do
      let(:pwm_pins) { { left: left_pwm } }

      it 'returns true only for configured motors' do
        expect(ramper.available?(:left)).to be true
        expect(ramper.available?(:right)).to be false
      end
    end
  end

  describe 'thread safety' do
    it 'handles concurrent ramp_up calls' do
      threads = []
      expect(left_pwm).to receive(:pwm).at_least(:once)
      expect(right_pwm).to receive(:pwm).at_least(:once)

      threads << Thread.new { ramper.ramp_up(:left) }
      threads << Thread.new { ramper.ramp_up(:right) }

      threads.each(&:join)
      sleep(0.15)
    end

    it 'handles concurrent stop calls' do
      expect(left_pwm).to receive(:pwm).at_least(:once)
      expect(right_pwm).to receive(:pwm).at_least(:once)

      ramper.ramp_up(:left)
      ramper.ramp_up(:right)

      threads = []
      threads << Thread.new { ramper.stop(:left) }
      threads << Thread.new { ramper.stop(:right) }

      threads.each(&:join)
    end
  end

  describe 'with default settings' do
    let(:settings) { {} }

    it 'uses default ramp duration of 500ms' do
      duty_cycles = []
      allow(left_pwm).to receive(:pwm) { |dc| duty_cycles << dc }

      ramper.ramp_up(:left)
      sleep(0.1)
      ramper.stop(:left)

      expect(duty_cycles).not_to be_empty
    end
  end
end
