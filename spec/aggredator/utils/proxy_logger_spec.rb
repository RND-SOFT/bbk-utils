RSpec.describe Aggredator::ProxyLogger do
  let(:progname) { SecureRandom.hex }
  let(:io) { StringIO.new('') }
  let(:output) { io.string }
  let(:tag) { SecureRandom.hex }
  let(:proxy) { described_class.new(logger, tags: tag) }

  context '::Logger' do
    let(:logger) { ::Logger.new(io) }

    it 'no tagging' do
      proxy.info(:message)

      expect(output).not_to match(/#{tag}/)
    end
  end

  context 'Tagged Logger' do
    let(:logger) { ActiveSupport::TaggedLogging.new(::Logger.new(io)) }

    it 'simple tagging' do
      proxy.info(:message)
      expect(output).to match(/#{tag}/)
    end

    it 'add tags' do
      proxy.add_tags('tag2')
      proxy.info(:message)
      expect(output).to match(/#{tag}/)
      expect(output).to match(/tag2/)
    end
  end
end
