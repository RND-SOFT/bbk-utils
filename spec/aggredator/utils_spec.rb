RSpec.describe Aggredator::Utils do

  subject { described_class }

  context '#gracefully_main' do
  
    it 'complete request' do
      action = Proc.new { 42 }
      expect(subject.gracefully_main &action).to eq 0
    end

    it 'failed by error' do
      code = 0
      expect{
        code = subject.gracefully_main { raise ValueError }
      }.not_to raise_error
      expect(code).to eq 1
    end

    it 'catch terminate signal' do
      code = 0
      expect {
        code = subject.gracefully_main { raise SignalException.new(Signal.list['TERM']) }
      }.not_to raise_error
      expect(code).to be_zero
    end

    it 'catch not terminate signal' do
      code = 0
      expect {
        code = subject.gracefully_main { raise SignalException.new(Signal.list['KILL']) }
      }.not_to raise_error
      expect(code).to eq 1
    end

  end

end