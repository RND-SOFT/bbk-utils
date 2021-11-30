RSpec.describe BBK::Logger do
  let(:progname) { SecureRandom.hex }
  let(:io) { StringIO.new('') }
  let(:output) { io.string }
  let(:tag) { SecureRandom.hex }

  it 'building' do
    logger = described_class.new progname, :debug, io: io
    expect(output).to match(/Using LOG_LEVEL/)
    expect(logger.level).to eq Logger::DEBUG
    expect(logger.formatter).to be_a BBK::LogFormatter
  end

  it 'default log level info' do
    logger = described_class.new progname, nil, io: io
    expect(output).to match(/Using LOG_LEVEL/)
    expect(logger.level).to eq Logger::INFO
    expect(logger.formatter).to be_a BBK::LogFormatter
  end

  it 'tagged' do
    logger = described_class.new progname, nil, io: io
    logger.tagged(tag) do
      logger.info('hello1')
    end
    expect(output).to match(/#{tag}.*hello1/)
  end

  it 'push_tags' do
    logger = described_class.new progname, nil, io: io
    logger.push_tags(tag)
    logger.info('hello2')
    expect(output).to match(/#{tag}.*hello2/)
  end

  it 'ActiveSupport::TaggedLogging' do
    expect(described_class.new(progname, nil, io: io)).to be_an(ActiveSupport::TaggedLogging)
  end
end
