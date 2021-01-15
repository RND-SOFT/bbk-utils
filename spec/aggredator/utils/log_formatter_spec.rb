RSpec.describe Aggredator::LogFormatter do
  let(:progname) { SecureRandom.hex }
  let(:severity) { Logger::Severity.constants.map(&:to_s).sample }
  let(:time) { Time.now - Random.rand(1..42).minutes }
  let(:message) { SecureRandom.hex }

  subject { described_class.new }

  it 'call' do
    expect(subject).to receive(:msg2str).with(message).and_call_original
    expect(subject).to receive(:format_datetime).with(time.utc)
    expect(subject).to receive(:format).with(described_class::FORMAT, severity, anything, $PROCESS_ID, progname, any_args)
    subject.call(severity, time, progname, message)
  end

  it 'thread id' do
    Thread.current.name = SecureRandom.hex
    value = subject.thread_id
    expect(value).to be_a String
    parts = value.split('@')
    expect(parts.size).to eq 2
    expect(parts.first).to eq Thread.current.object_id.to_s
    expect(parts.last).to eq Thread.current.name
  end
end
