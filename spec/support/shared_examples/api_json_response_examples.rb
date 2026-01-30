# frozen_string_literal: true

RSpec.shared_examples 'a JSON API response' do
  it 'returns JSON content type' do
    expect(last_response.content_type).to include('application/json')
  end

  it 'returns valid JSON' do
    expect { JSON.parse(last_response.body) }.not_to raise_error
  end
end

RSpec.shared_examples 'a successful API response' do
  it_behaves_like 'a JSON API response'

  it 'returns 200 status' do
    expect(last_response).to be_ok
  end

  it 'includes success: true' do
    expect(JSON.parse(last_response.body)['success']).to be true
  end
end

RSpec.shared_examples 'an error API response' do |status_code|
  it_behaves_like 'a JSON API response'

  it "returns #{status_code} status" do
    expect(last_response.status).to eq(status_code)
  end

  it 'includes success: false' do
    expect(JSON.parse(last_response.body)['success']).to be false
  end

  it 'includes error message' do
    expect(JSON.parse(last_response.body)['error']).to be_a(String)
  end
end
