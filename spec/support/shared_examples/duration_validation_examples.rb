# frozen_string_literal: true

RSpec.shared_examples 'duration validation' do |method_name, *args|
  context 'with nil duration' do
    it 'allows continuous movement' do
      result = subject.public_send(method_name, *args, duration: nil)
      expect(result[:duration]).to be_nil
    end
  end

  context 'with positive duration' do
    it 'accepts valid duration' do
      result = subject.public_send(method_name, *args, duration: 1000)
      expect(result[:duration]).to eq(1000)
    end
  end

  context 'with zero or negative duration' do
    it 'raises ArgumentError for zero' do
      expect { subject.public_send(method_name, *args, duration: 0) }
        .to raise_error(ArgumentError, 'Duration must be positive')
    end

    it 'raises ArgumentError for negative' do
      expect { subject.public_send(method_name, *args, duration: -100) }
        .to raise_error(ArgumentError, 'Duration must be positive')
    end
  end
end
