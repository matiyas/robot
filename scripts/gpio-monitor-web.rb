#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra/base'
require 'json'

# Web-based GPIO pin monitor
# Provides a real-time web interface for monitoring GPIO pin states
#
# Usage: ruby gpio-monitor-web.rb
# Then open: http://raspberry-pi-ip:8082
class GpioMonitorWeb < Sinatra::Base
  set :port, 8082
  set :bind, '0.0.0.0'

  # Pin configuration (from config/gpio_pins.yml)
  PINS = {
    left_motor: { in1: 17, in2: 18, name: 'Left Motor (Wheel)' },
    right_motor: { in1: 22, in2: 23, name: 'Right Motor (Wheel)' },
    turret_motor: { in1: 27, in2: 24, name: 'Turret Motor (Camera)' }
  }.freeze

  # Read a GPIO pin state
  def read_pin(pin)
    `pigs r #{pin}`.strip.to_i
  rescue StandardError
    -1
  end

  # Get motor state from IN1/IN2 pins
  def motor_state(in1, in2)
    case [in1, in2]
    when [0, 0] then 'COAST'
    when [1, 0] then 'FORWARD'
    when [0, 1] then 'BACKWARD'
    when [1, 1] then 'BRAKE'
    else 'UNKNOWN'
    end
  end

  # Main page
  get '/' do
    erb :monitor
  end

  # API endpoint for pin states
  get '/api/pins' do
    content_type :json

    data = PINS.transform_values do |config|
      in1_state = read_pin(config[:in1])
      in2_state = read_pin(config[:in2])

      {
        name: config[:name],
        in1: { pin: config[:in1], state: in1_state },
        in2: { pin: config[:in2], state: in2_state },
        motor_state: motor_state(in1_state, in2_state)
      }
    end

    { pins: data, timestamp: Time.now.to_i }.to_json
  end

  # HTML template
  template :monitor do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>GPIO Monitor - Robot Tank</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            padding: 20px;
            min-height: 100vh;
          }
          .container {
            max-width: 1200px;
            margin: 0 auto;
          }
          h1 {
            text-align: center;
            margin-bottom: 10px;
            font-size: 2em;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
          }
          .subtitle {
            text-align: center;
            margin-bottom: 30px;
            opacity: 0.9;
            font-size: 0.9em;
          }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
          }
          .motor-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 25px;
            border: 1px solid rgba(255, 255, 255, 0.2);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
          }
          .motor-name {
            font-size: 1.3em;
            font-weight: bold;
            margin-bottom: 20px;
            border-bottom: 2px solid rgba(255, 255, 255, 0.3);
            padding-bottom: 10px;
          }
          .pin-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin: 15px 0;
            padding: 12px;
            background: rgba(0, 0, 0, 0.2);
            border-radius: 8px;
          }
          .pin-label {
            font-size: 1.1em;
            font-weight: 500;
          }
          .pin-state {
            display: flex;
            align-items: center;
            gap: 10px;
          }
          .pin-value {
            font-family: 'Courier New', monospace;
            font-size: 1.2em;
            font-weight: bold;
            padding: 5px 15px;
            border-radius: 5px;
            min-width: 60px;
            text-align: center;
          }
          .pin-high {
            background: #4caf50;
            color: white;
            box-shadow: 0 0 10px rgba(76, 175, 80, 0.5);
          }
          .pin-low {
            background: #f44336;
            color: white;
          }
          .motor-state {
            margin-top: 20px;
            padding: 15px;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 8px;
            text-align: center;
            font-size: 1.2em;
            font-weight: bold;
          }
          .state-coast { color: #64b5f6; }
          .state-forward { color: #81c784; }
          .state-backward { color: #ffb74d; }
          .state-brake { color: #e57373; }
          .status-bar {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 10px;
            padding: 15px 25px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border: 1px solid rgba(255, 255, 255, 0.2);
          }
          .update-indicator {
            display: flex;
            align-items: center;
            gap: 10px;
          }
          .pulse {
            width: 12px;
            height: 12px;
            background: #4caf50;
            border-radius: 50%;
            animation: pulse 1.5s infinite;
          }
          @keyframes pulse {
            0%, 100% { opacity: 1; box-shadow: 0 0 10px #4caf50; }
            50% { opacity: 0.5; box-shadow: 0 0 5px #4caf50; }
          }
          .error {
            background: rgba(244, 67, 54, 0.2);
            color: #ffcdd2;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            margin: 20px 0;
            border: 1px solid rgba(244, 67, 54, 0.5);
          }
          @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            h1 { font-size: 1.5em; }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>🤖 GPIO Pin Monitor</h1>
          <div class="subtitle">Real-time Robot Tank Control Monitoring</div>

          <div id="error" class="error" style="display: none;"></div>

          <div class="grid" id="motorGrid"></div>

          <div class="status-bar">
            <div class="update-indicator">
              <div class="pulse"></div>
              <span>Live monitoring</span>
            </div>
            <div>Last update: <span id="lastUpdate">--:--:--</span></div>
          </div>
        </div>

        <script>
          const motorOrder = ['left_motor', 'right_motor', 'turret_motor'];

          function updatePins() {
            fetch('/api/pins')
              .then(response => response.json())
              .then(data => {
                document.getElementById('error').style.display = 'none';

                const grid = document.getElementById('motorGrid');
                grid.innerHTML = '';

                motorOrder.forEach(motorKey => {
                  const motor = data.pins[motorKey];
                  if (!motor) return;

                  const card = document.createElement('div');
                  card.className = 'motor-card';

                  const stateClass = 'state-' + motor.motor_state.toLowerCase();

                  card.innerHTML = `
                    <div class="motor-name">\${motor.name}</div>

                    <div class="pin-row">
                      <div class="pin-label">GPIO \${motor.in1.pin} (IN1)</div>
                      <div class="pin-state">
                        <span class="pin-value \${motor.in1.state === 1 ? 'pin-high' : 'pin-low'}">
                          \${motor.in1.state === 1 ? 'HIGH' : 'LOW'}
                        </span>
                      </div>
                    </div>

                    <div class="pin-row">
                      <div class="pin-label">GPIO \${motor.in2.pin} (IN2)</div>
                      <div class="pin-state">
                        <span class="pin-value \${motor.in2.state === 1 ? 'pin-high' : 'pin-low'}">
                          \${motor.in2.state === 1 ? 'HIGH' : 'LOW'}
                        </span>
                      </div>
                    </div>

                    <div class="motor-state \${stateClass}">
                      \${motor.motor_state}
                    </div>
                  `;

                  grid.appendChild(card);
                });

                const now = new Date();
                document.getElementById('lastUpdate').textContent =
                  now.toLocaleTimeString('en-US', { hour12: false });
              })
              .catch(error => {
                document.getElementById('error').style.display = 'block';
                document.getElementById('error').textContent =
                  'Connection error: ' + error.message;
              });
          }

          // Update every 200ms
          updatePins();
          setInterval(updatePins, 200);
        </script>
      </body>
      </html>
    HTML
  end
end

# Run the server
GpioMonitorWeb.run!
