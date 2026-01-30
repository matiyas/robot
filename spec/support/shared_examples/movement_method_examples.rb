# frozen_string_literal: true

RSpec.shared_examples 'a movement method' do |method_name|
  it 'accepts duration parameter' do
    expect { subject.public_send(method_name, duration: 1000) }.not_to raise_error
  end

  it 'works without duration' do
    expect { subject.public_send(method_name) }.not_to raise_error
  end
end
