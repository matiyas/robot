# frozen_string_literal: true

RSpec.shared_examples 'a controller implementing ControlInterface' do
  it { is_expected.to respond_to(:move_forward) }
  it { is_expected.to respond_to(:move_backward) }
  it { is_expected.to respond_to(:turn_left) }
  it { is_expected.to respond_to(:turn_right) }
  it { is_expected.to respond_to(:turret_left) }
  it { is_expected.to respond_to(:turret_right) }
  it { is_expected.to respond_to(:stop_motors) }
  it { is_expected.to respond_to(:cleanup) }
end
