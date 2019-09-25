RSpec.describe Aggredator::Logger do

  let(:progname) { SecureRandom.hex }
  let(:level) { Logger::Severity.constants.map(&:to_s).sample }

  it 'building' do
    expect_any_instance_of(described_class).to receive(:info).with(/Using LOG_LEVEL/)
    logger = described_class.new progname, level
    expect(logger.level).to eq Logger.const_get(level)
    expect(logger.formatter).to be_a Aggredator::LogFormatter
  end

  it 'default log level info' do
    expect_any_instance_of(described_class).to receive(:info).with(/Using LOG_LEVEL/)
    logger = described_class.new progname, nil
    expect(logger.level).to eq Logger::INFO
    expect(logger.formatter).to be_a Aggredator::LogFormatter
  end

  it 'silence' do
    logger = described_class.new progname, 'ERROR'
    result = logger.silence {|v| v}
    expect(result).to eq logger
  end

end