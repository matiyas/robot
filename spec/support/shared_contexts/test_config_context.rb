# frozen_string_literal: true

RSpec.shared_context 'with test settings' do
  let(:test_settings) do
    {
      'host' => '0.0.0.0',
      'port' => 4567,
      'movement_timeout' => 5000,
      'turret_timeout' => 2000,
      'log_level' => 'debug',
      'auth_enabled' => false,
      'gpio_enabled' => false,
      'camera_url' => 'http://localhost:8081'
    }
  end

  let(:production_settings) do
    test_settings.merge(
      'port' => 80,
      'gpio_enabled' => true,
      'log_level' => 'info'
    )
  end

  let(:development_settings) do
    test_settings.merge(
      'movement_timeout' => 1000,
      'turret_timeout' => 500
    )
  end
end
