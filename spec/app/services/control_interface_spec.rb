# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../app/services/control_interface'

RSpec.describe ControlInterface do
  subject(:interface) { described_class.new }

  it_behaves_like 'a controller implementing ControlInterface'

  describe 'abstract method enforcement' do
    describe '#move_forward' do
      it 'raises NotImplementedError' do
        expect { interface.move_forward }
          .to raise_error(NotImplementedError, /must implement #move_forward/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.move_forward(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #move_forward/)
      end
    end

    describe '#move_backward' do
      it 'raises NotImplementedError' do
        expect { interface.move_backward }
          .to raise_error(NotImplementedError, /must implement #move_backward/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.move_backward(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #move_backward/)
      end
    end

    describe '#turn_left' do
      it 'raises NotImplementedError' do
        expect { interface.turn_left }
          .to raise_error(NotImplementedError, /must implement #turn_left/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.turn_left(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #turn_left/)
      end
    end

    describe '#turn_right' do
      it 'raises NotImplementedError' do
        expect { interface.turn_right }
          .to raise_error(NotImplementedError, /must implement #turn_right/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.turn_right(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #turn_right/)
      end
    end

    describe '#turret_left' do
      it 'raises NotImplementedError' do
        expect { interface.turret_left }
          .to raise_error(NotImplementedError, /must implement #turret_left/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.turret_left(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #turret_left/)
      end
    end

    describe '#turret_right' do
      it 'raises NotImplementedError' do
        expect { interface.turret_right }
          .to raise_error(NotImplementedError, /must implement #turret_right/)
      end

      it 'raises NotImplementedError with duration parameter' do
        expect { interface.turret_right(duration: 1000) }
          .to raise_error(NotImplementedError, /must implement #turret_right/)
      end
    end

    describe '#stop_motors' do
      it 'raises NotImplementedError' do
        expect { interface.stop_motors }
          .to raise_error(NotImplementedError, /must implement #stop_motors/)
      end
    end

    describe '#cleanup' do
      it 'raises NotImplementedError' do
        expect { interface.cleanup }
          .to raise_error(NotImplementedError, /must implement #cleanup/)
      end
    end
  end
end
