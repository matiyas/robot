# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/servo_controller'

RSpec.describe ServoController do
  subject(:controller) { described_class.new(servo_pin, test_settings, test_logger) }

  include_context 'with test logger'

  let(:servo_pin) { instance_double(Pigpio::UserGPIO) }
  let(:pwm_object) { instance_double(Pigpio::PWM) }

  let(:test_settings) do
    {
      'servo_min_pulse' => 500,
      'servo_max_pulse' => 2400,
      'servo_min_angle' => 0,
      'servo_max_angle' => 180,
      'servo_default_angle' => 90,
      'servo_step_angle' => 10,
      'servo_smooth_step' => 10,
      'servo_smooth_delay_ms' => 1
    }
  end

  before do
    allow(servo_pin).to receive(:pwm).and_return(pwm_object)
    allow(pwm_object).to receive(:servo_pulsewidth=)
  end

  describe '#initialize' do
    it 'sets servo to default angle' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(kind_of(Integer))
      described_class.new(servo_pin, test_settings, test_logger)
    end

    it 'logs initialization' do
      described_class.new(servo_pin, test_settings, test_logger)
      expect(logged_info.any? { |msg| msg.include?('ServoController initialized at 90 degrees') }).to be true
    end

    it 'uses default values when settings are missing' do
      minimal_settings = {}
      servo = described_class.new(servo_pin, minimal_settings, test_logger)
      expect(servo.current_angle).to eq(90)
    end
  end

  describe '#move_to' do
    it 'sets servo to specified angle' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(kind_of(Integer)).at_least(:once)
      controller.move_to(45)
      expect(controller.current_angle).to eq(45)
    end

    it 'clamps angle to minimum' do
      controller.move_to(-10)
      expect(controller.current_angle).to eq(0)
    end

    it 'clamps angle to maximum' do
      controller.move_to(200)
      expect(controller.current_angle).to eq(180)
    end

    it 'converts angle to correct pulse width for 0 degrees' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(500).at_least(:once)
      controller.move_to(0)
    end

    it 'converts angle to correct pulse width for 180 degrees' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(2400).at_least(:once)
      controller.move_to(180)
    end

    it 'converts angle to correct pulse width for 90 degrees' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(1450).at_least(:once)
      controller.move_to(90)
    end

    it 'logs the angle change' do
      controller.move_to(45)
      expect(logged_debug.any? { |msg| msg.include?('Servo moved to 45 degrees') }).to be true
    end

    context 'with smooth movement disabled' do
      it 'moves directly without interpolation' do
        controller.move_to(45, smooth: false)
        expect(controller.current_angle).to eq(45)
      end
    end
  end

  describe '#step_left' do
    before { controller.move_to(90, smooth: false) }

    it 'decreases angle by step_angle' do
      controller.step_left
      expect(controller.current_angle).to eq(80)
    end

    it 'respects minimum angle' do
      controller.move_to(5, smooth: false)
      controller.step_left
      expect(controller.current_angle).to eq(0)
    end

    it 'logs the step' do
      controller.step_left
      expect(logged_debug.any? { |msg| msg.include?('Servo stepped left') }).to be true
    end
  end

  describe '#step_right' do
    before { controller.move_to(90, smooth: false) }

    it 'increases angle by step_angle' do
      controller.step_right
      expect(controller.current_angle).to eq(100)
    end

    it 'respects maximum angle' do
      controller.move_to(175, smooth: false)
      controller.step_right
      expect(controller.current_angle).to eq(180)
    end

    it 'logs the step' do
      controller.step_right
      expect(logged_debug.any? { |msg| msg.include?('Servo stepped right') }).to be true
    end
  end

  describe '#center' do
    it 'moves to default angle' do
      controller.move_to(45, smooth: false)
      controller.center
      expect(controller.current_angle).to eq(90)
    end

    it 'logs centering' do
      controller.center
      expect(logged_debug.any? { |msg| msg.include?('Servo centered') }).to be true
    end
  end

  describe '#stop' do
    it 'does not raise error' do
      expect { controller.stop }.not_to raise_error
    end
  end

  describe '#release' do
    it 'sets pulsewidth to 0' do
      expect(pwm_object).to receive(:servo_pulsewidth=).with(0)
      controller.release
    end

    it 'logs release' do
      controller.release
      expect(logged_debug.any? { |msg| msg.include?('Servo released') }).to be true
    end
  end

  describe '#cleanup' do
    it 'releases the servo' do
      expect(controller).to receive(:release)
      controller.cleanup
    end

    it 'logs cleanup' do
      controller.cleanup
      expect(logged_info.any? { |msg| msg.include?('ServoController cleanup') }).to be true
    end
  end

  describe '#current_angle' do
    it 'returns the current angle' do
      controller.move_to(60, smooth: false)
      expect(controller.current_angle).to eq(60)
    end
  end

  describe 'smooth movement' do
    let(:test_settings) do
      {
        'servo_min_pulse' => 500,
        'servo_max_pulse' => 2400,
        'servo_min_angle' => 0,
        'servo_max_angle' => 180,
        'servo_default_angle' => 90,
        'servo_step_angle' => 10,
        'servo_smooth_step' => 5,
        'servo_smooth_delay_ms' => 1
      }
    end

    it 'interpolates between positions' do
      controller.move_to(90, smooth: false)
      pulsewidths = []
      allow(pwm_object).to receive(:servo_pulsewidth=) { |val| pulsewidths << val }

      controller.move_to(100)

      expect(pulsewidths.length).to be > 1
      expect(pulsewidths.last).to be_within(1).of(1556)
    end

    it 'moves in correct direction for decreasing angle' do
      controller.move_to(90, smooth: false)
      pulsewidths = []
      allow(pwm_object).to receive(:servo_pulsewidth=) { |val| pulsewidths << val }

      controller.move_to(80)

      expect(pulsewidths).to all(be <= 1450)
    end
  end
end
