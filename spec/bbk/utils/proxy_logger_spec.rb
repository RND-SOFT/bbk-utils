RSpec.describe BBK::ProxyLogger do
  let(:progname) { SecureRandom.hex }
  let(:io) { StringIO.new('') }
  let(:output) { io.string }
  let(:tag) { SecureRandom.hex }
  let(:proxy) { described_class.new(logger, tags: tag) }

  context '::Logger' do
    let(:logger) { ::Logger.new(io) }

    it 'no tagging' do
      proxy.info(:message)
      expect(output.strip).to match('message')
    end
  end

  context 'Tagged Logger' do
    let(:logger) { ActiveSupport::TaggedLogging.new(::Logger.new(io)) }

    it 'simple tagging' do
      proxy.info(:message)
      expect(output.strip).to match("[#{tag}] message")
    end

    it 'add tags' do
      proxy.add_tags('tag2')
      proxy.info(:message)
      expect(output.strip).to match("[#{tag}] [tag2] message")
    end

    it 'tagged' do
      proxy.tagged('tag3') { proxy.info(:message) }
      expect(output.strip).to match("[#{tag}] [tag3] message")
    end
  end
end
