# frozen_string_literal: true

require 'spec_helper'
require 'sinatra/base'
require 'json'
require_relative '../../../app/helpers/api_helpers'

RSpec.describe ApiHelpers do
  # Create a minimal Sinatra app that includes the helpers
  let(:app) do
    Class.new(Sinatra::Base) do
      helpers ApiHelpers

      get '/test_json' do
        json_response({ test: 'data' }, 200)
      end

      get '/test_json_custom_status' do
        json_response({ error: 'not found' }, 404)
      end

      get '/test_success' do
        success_response
      end

      get '/test_success_with_data' do
        success_response(action: 'move', direction: 'forward')
      end

      get '/test_error_default' do
        error_response('Something went wrong')
      end

      get '/test_error_custom_status' do
        error_response('Unauthorized', 401)
      end

      post '/test_validate' do
        data = parse_json_body
        direction = data['direction']
        validate_direction(direction, %w[forward backward left right])
        success_response(direction: direction)
      end

      post '/test_parse' do
        data = parse_json_body
        success_response(data)
      end
    end
  end

  include Rack::Test::Methods

  describe '#json_response' do
    context 'with default status' do
      before { get '/test_json' }

      it 'returns 200 status by default' do
        expect(last_response).to be_ok
      end

      it 'sets JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'returns valid JSON' do
        expect { JSON.parse(last_response.body) }.not_to raise_error
      end

      it 'includes the provided data' do
        expect(JSON.parse(last_response.body)).to eq({ 'test' => 'data' })
      end
    end

    context 'with custom status' do
      before { get '/test_json_custom_status' }

      it 'returns the specified status code' do
        expect(last_response.status).to eq(404)
      end

      it 'includes the provided data' do
        expect(JSON.parse(last_response.body)).to eq({ 'error' => 'not found' })
      end
    end
  end

  describe '#success_response' do
    context 'without data' do
      before { get '/test_success' }

      it 'returns 200 status' do
        expect(last_response).to be_ok
      end

      it 'sets JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'includes success: true' do
        body = JSON.parse(last_response.body)
        expect(body['success']).to be true
      end

      it 'returns only success field' do
        body = JSON.parse(last_response.body)
        expect(body.keys).to eq(['success'])
      end
    end

    context 'with data' do
      before { get '/test_success_with_data' }

      it 'returns 200 status' do
        expect(last_response).to be_ok
      end

      it 'includes success: true' do
        body = JSON.parse(last_response.body)
        expect(body['success']).to be true
      end

      it 'merges additional data' do
        body = JSON.parse(last_response.body)
        expect(body['action']).to eq('move')
        expect(body['direction']).to eq('forward')
      end
    end
  end

  describe '#error_response' do
    context 'with default status' do
      before { get '/test_error_default' }

      it 'returns 400 status by default' do
        expect(last_response.status).to eq(400)
      end

      it 'sets JSON content type' do
        expect(last_response.content_type).to include('application/json')
      end

      it 'includes success: false' do
        body = JSON.parse(last_response.body)
        expect(body['success']).to be false
      end

      it 'includes error message' do
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Something went wrong')
      end
    end

    context 'with custom status' do
      before { get '/test_error_custom_status' }

      it 'returns the specified status code' do
        expect(last_response.status).to eq(401)
      end

      it 'includes success: false' do
        body = JSON.parse(last_response.body)
        expect(body['success']).to be false
      end

      it 'includes error message' do
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Unauthorized')
      end
    end
  end

  describe '#validate_direction' do
    context 'with valid direction' do
      it 'allows forward' do
        post '/test_validate', { direction: 'forward' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end

      it 'allows backward' do
        post '/test_validate', { direction: 'backward' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end

      it 'allows left' do
        post '/test_validate', { direction: 'left' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end

      it 'allows right' do
        post '/test_validate', { direction: 'right' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response).to be_ok
      end
    end

    context 'with invalid direction' do
      it 'halts with 400 status' do
        post '/test_validate', { direction: 'invalid' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end

      it 'returns error message' do
        post '/test_validate', { direction: 'invalid' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('Invalid direction')
        expect(body['error']).to include('forward, backward, left, right')
      end

      it 'includes success: false' do
        post '/test_validate', { direction: 'invalid' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['success']).to be false
      end
    end

    context 'with nil direction' do
      it 'halts with 400 status' do
        post '/test_validate', { direction: nil }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end
    end

    context 'with empty string direction' do
      it 'halts with 400 status' do
        post '/test_validate', { direction: '' }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe '#parse_json_body' do
    context 'with valid JSON' do
      it 'parses and returns hash' do
        post '/test_parse', { key: 'value', number: 42 }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['key']).to eq('value')
        expect(body['number']).to eq(42)
      end

      it 'handles nested objects' do
        post '/test_parse', { outer: { inner: 'value' } }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['outer']['inner']).to eq('value')
      end

      it 'handles arrays' do
        post '/test_parse', { items: [1, 2, 3] }.to_json,
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['items']).to eq([1, 2, 3])
      end
    end

    context 'with invalid JSON' do
      it 'halts with 400 status' do
        post '/test_parse', 'not valid json',
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end

      it 'returns error message' do
        post '/test_parse', 'not valid json',
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Invalid JSON in request body')
      end

      it 'includes success: false' do
        post '/test_parse', 'not valid json',
             { 'CONTENT_TYPE' => 'application/json' }
        body = JSON.parse(last_response.body)
        expect(body['success']).to be false
      end
    end

    context 'with empty body' do
      it 'halts with 400 status' do
        post '/test_parse', '',
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end
    end

    context 'with malformed JSON' do
      it 'halts with 400 status for incomplete object' do
        post '/test_parse', '{"key":',
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end

      it 'halts with 400 status for trailing comma' do
        post '/test_parse', '{"key":"value",}',
             { 'CONTENT_TYPE' => 'application/json' }
        expect(last_response.status).to eq(400)
      end
    end
  end
end
