# frozen_string_literal: true

FactoryBot.define do
  factory :default_settings, class: Hash do
    initialize_with do
      {
        'host' => '0.0.0.0',
        'port' => 4567,
        'movement_timeout' => 5000,
        'turret_timeout' => 2000,
        'log_level' => 'info',
        'auth_enabled' => false,
        'gpio_enabled' => false,
        'camera_url' => 'http://localhost:8081'
      }
    end

    skip_create
  end

  factory :production_settings, parent: :default_settings do
    initialize_with do
      attributes_for(:default_settings).merge(
        'port' => 80,
        'gpio_enabled' => true,
        'log_level' => 'info'
      )
    end
  end

  factory :test_settings, parent: :default_settings do
    initialize_with do
      attributes_for(:default_settings).merge(
        'log_level' => 'debug',
        'movement_timeout' => 1000,
        'turret_timeout' => 500
      )
    end
  end

  factory :gpio_pin_config, class: Hash do
    initialize_with do
      {
        'motor_left' => { 'in1' => 17, 'in2' => 18 },
        'motor_right' => { 'in1' => 22, 'in2' => 23 },
        'motor_turret' => { 'in1' => 27, 'in2' => 24 }
      }
    end

    skip_create
  end
end
