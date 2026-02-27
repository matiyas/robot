# frozen_string_literal: true

RSpec.shared_context 'with mocked GPIO pins' do
  let(:gpio_manager) { instance_double(GpioManager) }

  let(:left_motor) do
    {
      in1: instance_double(Pigpio::IF::GPIO, write: nil),
      in2: instance_double(Pigpio::IF::GPIO, write: nil)
    }
  end

  let(:right_motor) do
    {
      in1: instance_double(Pigpio::IF::GPIO, write: nil),
      in2: instance_double(Pigpio::IF::GPIO, write: nil)
    }
  end

  let(:turret_motor) do
    {
      in1: instance_double(Pigpio::IF::GPIO, write: nil),
      in2: instance_double(Pigpio::IF::GPIO, write: nil)
    }
  end

  let(:pwm_pins) do
    {
      left: instance_double(Pigpio::IF::GPIO, pwm: nil),
      right: instance_double(Pigpio::IF::GPIO, pwm: nil),
      turret: instance_double(Pigpio::IF::GPIO, pwm: nil)
    }
  end

  before do
    allow(gpio_manager).to receive_messages(
      left_motor: left_motor,
      right_motor: right_motor,
      turret_motor: turret_motor,
      pwm_pins: pwm_pins
    )
    allow(gpio_manager).to receive(:cleanup)
    allow(gpio_manager).to receive(:stop_motors)
  end
end
