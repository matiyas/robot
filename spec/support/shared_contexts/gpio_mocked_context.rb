# frozen_string_literal: true

RSpec.shared_context 'with mocked GPIO pins' do
  let(:gpio_manager) { instance_double(GpioManager) }

  let(:left_motor) do
    {
      in1: instance_double(PiPiper::Pin, on: nil, off: nil),
      in2: instance_double(PiPiper::Pin, on: nil, off: nil)
    }
  end

  let(:right_motor) do
    {
      in1: instance_double(PiPiper::Pin, on: nil, off: nil),
      in2: instance_double(PiPiper::Pin, on: nil, off: nil)
    }
  end

  let(:turret_motor) do
    {
      in1: instance_double(PiPiper::Pin, on: nil, off: nil),
      in2: instance_double(PiPiper::Pin, on: nil, off: nil)
    }
  end

  before do
    allow(gpio_manager).to receive_messages(left_motor: left_motor, right_motor: right_motor, turret_motor: turret_motor)
    allow(gpio_manager).to receive(:cleanup)
    allow(gpio_manager).to receive(:stop_motors)
  end
end
