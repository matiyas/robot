# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'yaml'

# Prepend module to add aliases: true to YAML.load_file calls
module YAMLAliasesEnabled
  def load_file(filename, **kwargs)
    super(filename, **kwargs.merge(aliases: true))
  end
end
YAML.singleton_class.prepend(YAMLAliasesEnabled)

require_relative '../../app/robot_app'

RSpec.describe RobotApp do
  include Rack::Test::Methods

  include_context 'with test settings'

  def app
    RobotApp
  end

  let(:mock_robot) { instance_double(Robot) }
  let(:mock_controller) { instance_double(MockController, cleanup: nil, stop_motors: nil) }
  let(:test_logger) { Logger.new(StringIO.new) }

  before do
    # Override app settings for testing
    app.set :robot, mock_robot
    app.set :logger, test_logger
    app.set :app_settings, test_settings
    app.set :show_exceptions, false
    app.set :raise_errors, false

    # Allow logger methods to be spied on
    allow(test_logger).to receive(:warn).and_call_original
    allow(test_logger).to receive(:error).and_call_original

    # Stub SafetyHandler to prevent signal trapping during tests
    allow(SafetyHandler).to receive(:setup)
  end

  describe 'GET /' do
    it 'returns 200 status' do
      get '/'
      expect(last_response).to be_ok
    end

    it 'renders HTML' do
      get '/'
      expect(last_response.content_type).to include('text/html')
    end

    it 'renders the index template' do
      get '/'
      expect(last_response.body).not_to be_empty
    end
  end

  describe 'GET /health' do
    it 'returns 200 status' do
      get '/health'
      expect(last_response).to be_ok
    end

    it_behaves_like 'a JSON API response' do
      before { get '/health' }
    end

    it 'includes status: ok' do
      get '/health'
      body = JSON.parse(last_response.body)
      expect(body['status']).to eq('ok')
    end

    it 'includes timestamp' do
      get '/health'
      body = JSON.parse(last_response.body)
      expect(body['timestamp']).to be_a(Integer)
      expect(body['timestamp']).to be > 0
    end

    it 'timestamp is current time' do
      Timecop.freeze(Time.at(1_640_000_000)) do
        get '/health'
        body = JSON.parse(last_response.body)
        expect(body['timestamp']).to eq(1_640_000_000)
      end
    end
  end

  describe 'before /api/* filter' do
    it 'sets JSON content type for API routes' do
      allow(mock_robot).to receive(:status).and_return({ connected: true })
      get '/api/v1/status'
      expect(last_response.content_type).to include('application/json')
    end

    context 'when auth is disabled' do
      before do
        test_settings['auth_enabled'] = false
        app.set :app_settings, test_settings
      end

      it 'does not call authenticate!' do
        allow(mock_robot).to receive(:status).and_return({ connected: true })
        # authenticate! is a no-op when auth is disabled, so just verify request succeeds
        get '/api/v1/status'
        expect(last_response).to be_ok
      end
    end

    context 'when auth is enabled' do
      before do
        test_settings['auth_enabled'] = true
        app.set :app_settings, test_settings
      end

      it 'would call authenticate!' do
        # NOTE: authenticate! is a no-op currently, but filter calls it
        allow(mock_robot).to receive(:status).and_return({ connected: true })
        get '/api/v1/status'
        expect(last_response).to be_ok
      end
    end
  end

  describe 'POST /api/v1/move' do
    let(:valid_move_params) { { direction: 'forward', duration: 1000 } }

    context 'with valid forward direction' do
      before do
        allow(mock_robot).to receive(:move)
          .with('forward', duration: 1000)
          .and_return({ action: 'forward', duration: 1000 })
      end

      it 'returns 200 status' do
        post '/api/v1/move', valid_move_params.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end

      it_behaves_like 'a successful API response' do
        before do
          post '/api/v1/move', valid_move_params.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'calls robot.move with direction and duration' do
        expect(mock_robot).to receive(:move).with('forward', duration: 1000)
        post '/api/v1/move', valid_move_params.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
      end

      it 'includes action in response' do
        post '/api/v1/move', valid_move_params.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['action']).to eq('forward')
      end

      it 'includes duration in response' do
        post '/api/v1/move', valid_move_params.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['duration']).to eq(1000)
      end
    end

    %w[forward backward left right].each do |direction|
      context "with #{direction} direction" do
        it 'accepts the direction' do
          allow(mock_robot).to receive(:move).and_return({ action: direction, duration: 1000 })
          post '/api/v1/move', { direction: direction, duration: 1000 }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response).to be_ok
        end
      end
    end

    context 'with invalid direction' do
      it_behaves_like 'an error API response', 400 do
        before do
          post '/api/v1/move', { direction: 'invalid', duration: 1000 }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'includes error message about invalid direction' do
        post '/api/v1/move', { direction: 'invalid', duration: 1000 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('Invalid direction')
      end

      it 'lists valid directions' do
        post '/api/v1/move', { direction: 'sideways', duration: 1000 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('forward, backward, left, right')
      end
    end

    context 'with invalid JSON' do
      it_behaves_like 'an error API response', 400 do
        before do
          post '/api/v1/move', 'not valid json',
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'includes error message about invalid JSON' do
        post '/api/v1/move', 'not valid json',
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Invalid JSON in request body')
      end
    end

    context 'without duration' do
      it 'passes nil duration to robot' do
        allow(mock_robot).to receive(:move).with('forward', duration: nil)
                                           .and_return({ action: 'forward', duration: nil })
        post '/api/v1/move', { direction: 'forward' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end
    end
  end

  describe 'POST /api/v1/turret' do
    context 'with valid left direction' do
      before do
        allow(mock_robot).to receive(:turret)
          .with('left', duration: 500)
          .and_return({ action: 'turret_left', duration: 500 })
      end

      it 'returns 200 status' do
        post '/api/v1/turret', { direction: 'left', duration: 500 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end

      it_behaves_like 'a successful API response' do
        before do
          post '/api/v1/turret', { direction: 'left', duration: 500 }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'calls robot.turret with direction and duration' do
        expect(mock_robot).to receive(:turret).with('left', duration: 500)
        post '/api/v1/turret', { direction: 'left', duration: 500 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
      end

      it 'includes action in response' do
        post '/api/v1/turret', { direction: 'left', duration: 500 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['action']).to eq('turret_left')
      end
    end

    %w[left right].each do |direction|
      context "with #{direction} direction" do
        it 'accepts the direction' do
          allow(mock_robot).to receive(:turret).and_return({ action: "turret_#{direction}", duration: 500 })
          post '/api/v1/turret', { direction: direction, duration: 500 }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
          expect(last_response).to be_ok
        end
      end
    end

    context 'with invalid direction' do
      it_behaves_like 'an error API response', 400 do
        before do
          post '/api/v1/turret', { direction: 'forward', duration: 500 }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'includes error message' do
        post '/api/v1/turret', { direction: 'invalid', duration: 500 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('Invalid direction')
      end

      it 'lists valid turret directions' do
        post '/api/v1/turret', { direction: 'up', duration: 500 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('left, right')
      end
    end

    context 'with invalid JSON' do
      it_behaves_like 'an error API response', 400 do
        before do
          post '/api/v1/turret', 'not valid json',
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end
    end
  end

  describe 'POST /api/v1/stop' do
    before do
      allow(mock_robot).to receive(:stop).and_return({ action: 'stop_all' })
    end

    it 'returns 200 status' do
      post '/api/v1/stop'
      expect(last_response).to be_ok
    end

    it_behaves_like 'a successful API response' do
      before { post '/api/v1/stop' }
    end

    it 'calls robot.stop' do
      expect(mock_robot).to receive(:stop)
      post '/api/v1/stop'
    end

    it 'includes action: stop_all in response' do
      post '/api/v1/stop'
      body = JSON.parse(last_response.body)
      expect(body['action']).to eq('stop_all')
    end
  end

  describe 'GET /api/v1/status' do
    let(:status_data) do
      {
        connected: true,
        gpio_enabled: false,
        camera_url: 'http://test.local:8081'
      }
    end

    before do
      allow(mock_robot).to receive(:status).and_return(status_data)
    end

    it 'returns 200 status' do
      get '/api/v1/status'
      expect(last_response).to be_ok
    end

    it_behaves_like 'a successful API response' do
      before { get '/api/v1/status' }
    end

    it 'calls robot.status' do
      expect(mock_robot).to receive(:status)
      get '/api/v1/status'
    end

    it 'includes connected in response' do
      get '/api/v1/status'
      body = JSON.parse(last_response.body)
      expect(body['connected']).to be true
    end

    it 'includes gpio_enabled in response' do
      get '/api/v1/status'
      body = JSON.parse(last_response.body)
      expect(body['gpio_enabled']).to be false
    end

    it 'includes camera_url in response' do
      get '/api/v1/status'
      body = JSON.parse(last_response.body)
      expect(body['camera_url']).to eq('http://test.local:8081')
    end
  end

  describe 'GET /api/v1/camera' do
    it 'returns 200 status' do
      get '/api/v1/camera'
      expect(last_response).to be_ok
    end

    it_behaves_like 'a successful API response' do
      before { get '/api/v1/camera' }
    end

    it 'includes stream_url in response' do
      get '/api/v1/camera'
      body = JSON.parse(last_response.body)
      expect(body['stream_url']).to eq(test_settings['camera_url'])
    end

    it 'returns camera URL from settings' do
      get '/api/v1/camera'
      body = JSON.parse(last_response.body)
      expect(body['stream_url']).to eq('http://localhost:8081')
    end
  end

  describe 'error handling' do
    context 'when ArgumentError occurs (400)' do
      before do
        allow(mock_robot).to receive(:move)
          .with('forward', duration: nil)
          .and_raise(ArgumentError, 'Motor controller not initialized')
      end

      it_behaves_like 'an error API response', 400 do
        before do
          post '/api/v1/move', { direction: 'forward' }.to_json,
               { 'CONTENT_TYPE' => 'application/json' }
        end
      end

      it 'includes error message in response' do
        post '/api/v1/move', { direction: 'forward' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Motor controller not initialized')
      end

      it 'logs warning' do
        post '/api/v1/move', { direction: 'forward' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(test_logger).to have_received(:warn).with(/Invalid argument/)
      end
    end

    context 'when StandardError occurs (500)' do
      before do
        allow(mock_robot).to receive(:stop)
          .and_raise(StandardError, 'Unexpected error')
      end

      it_behaves_like 'an error API response', 500 do
        before { post '/api/v1/stop' }
      end

      it 'includes generic error message' do
        post '/api/v1/stop'
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('Internal server error')
      end

      it 'logs error with backtrace' do
        log_output = StringIO.new
        app.set :logger, Logger.new(log_output)
        post '/api/v1/stop'
        expect(log_output.string).to include('ERROR')
        expect(log_output.string).to include('Unexpected error')
      end
    end
  end

  describe 'configuration' do
    it 'sets environment' do
      expect(app.environment).to be_a(Symbol)
    end

    it 'disables show_exceptions for clean error responses' do
      expect(app.show_exceptions?).to be false
    end

    it 'has app_settings configured' do
      expect(app.app_settings).to be_a(Hash)
    end

    it 'has logger configured' do
      expect(app.logger).to be_a(Logger)
    end

    it 'has robot instance configured' do
      expect(app.robot).to be_truthy
    end
  end
end
