RSpec.describe BBK::Utils::LogFormatter do
  subject { described_class.new(filter:) }

  let(:progname) { SecureRandom.hex }
  let(:severity) { Logger::Severity.constants.map(&:to_s).sample }
  let(:time) { Time.now - Random.rand(1..42).minutes }
  let(:message) { SecureRandom.hex }
  let(:filter) { nil }

  it 'call' do
    expect(subject).to receive(:msg2str).with(message).and_call_original
    expect(subject).to receive(:format_datetime).with(time.utc)
    expect(subject).to receive(:format).with(described_class::FORMAT, severity, anything, $PROCESS_ID, progname,
                                             any_args).and_call_original
    expect(subject).to receive(:try_filtering).with(message).and_call_original
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

  describe 'with filter' do
    let(:filter) { double("Filter", filter: message)}

    context 'with simple message' do
      it 'call' do
        expect(filter).not_to receive(:filter)
        subject.call(severity, time, progname, message)
      end
    end

    context 'with hash message' do
      let(:message) { { test: SecureRandom.hex} }

      it 'call' do
        expect(filter).to receive(:filter).with(message).and_return(message)
        subject.call(severity, time, progname, message)
      end
    end

    context 'with object responding to to_h' do
      let(:message) do
        Struct.new(:test).new(SecureRandom.hex)
      end

      it 'call' do
        expect(filter).to receive(:filter).with(message.to_h).and_return(message.to_h)

        subject.call(severity, time, progname, message)
      end
    end

    context 'with string' do
      let(:message) { '42' }

      it 'call' do
        expect(filter).not_to receive(:filter)

        subject.call(severity, time, progname, message)
      end
    end
  end

end
