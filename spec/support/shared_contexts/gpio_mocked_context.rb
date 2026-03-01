# frozen_string_literal: true

RSpec.shared_context 'with mocked GPIO pins' do
  let(:gpio_manager) { instance_double(GpioManager) }

  let(:left_motor) do
    {
      in1: instance_double(Pigpio::UserGPIO, write: nil),
      in2: instance_double(Pigpio::UserGPIO, write: nil)
    }
  end

  let(:right_motor) do
    {
      in1: instance_double(Pigpio::UserGPIO, write: nil),
      in2: instance_double(Pigpio::UserGPIO, write: nil)
    }
  end

  let(:pwm_mock_object) { instance_double(Pigpio::PWM, 'dutycycle=': nil) }

  let(:pwm_pins) do
    left_pin = instance_double(Pigpio::UserGPIO)
    right_pin = instance_double(Pigpio::UserGPIO)
    allow(left_pin).to receive(:pwm).and_return(pwm_mock_object)
    allow(right_pin).to receive(:pwm).and_return(pwm_mock_object)
    { left: left_pin, right: right_pin }
  end

  let(:servo_pwm_object) { instance_double(Pigpio::PWM, 'servo_pulsewidth=': nil) }

  let(:servo_pin) do
    pin = instance_double(Pigpio::UserGPIO)
    allow(pin).to receive(:pwm).and_return(servo_pwm_object)
    pin
  end

  before do
    allow(gpio_manager).to receive_messages(
      left_motor: left_motor,
      right_motor: right_motor,
      pwm_pins: pwm_pins,
      servo_pin: servo_pin
    )
    allow(gpio_manager).to receive(:cleanup)
    allow(gpio_manager).to receive(:stop_motors)
  end
end
