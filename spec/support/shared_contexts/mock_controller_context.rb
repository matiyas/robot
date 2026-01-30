# frozen_string_literal: true

RSpec.shared_context 'with mock controller' do
  let(:mock_controller) do
    instance_double(
      MockController,
      move_forward: nil,
      move_backward: nil,
      turn_left: nil,
      turn_right: nil,
      turret_left: nil,
      turret_right: nil,
      stop_motors: nil,
      cleanup: nil
    )
  end
end
