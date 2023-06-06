require 'stringio'

RSpec.describe BBK::Utils::CombinedLogger do

  let(:first_io) { StringIO.new }
  let(:second_io) { StringIO.new }

  let(:first_logger) { BBK::Utils::Logger.new('first', 'warn', io: first_io) }
  let(:second_logger) { BBK::Utils::Logger.new('second', 'warn', io: second_io) }

  let(:progname) { 'test progname' }

  subject { described_class.new(progname, first_logger, second_logger) }

  def rewind_io
    [first_io, second_io].map{|it| it.seek(0)}
  end

  def clear_io
    rewind_io
    [first_io, second_io].map{|it| it.truncate(0)}
  end

  it 'ignore by log level' do
    subject.level = :warn
    subject.debug 'message'
    first_io.seek(0)
    expect(first_io.size).to be_zero
    expect(second_io.size).to be_zero
  end

  it 'log data to all output' do
    subject.info 'message'
    expect(first_io.size).not_to be_zero
    expect(second_io.size).not_to be_zero
  end

  it 'configure progname' do
    subject.level = :debug
    subject.progname = SecureRandom.hex
    subject.warn 'message'
    rewind_io
    expect(first_io.read).to match(subject.progname)
    expect(second_io.read).to match(subject.progname)
  end

  it 'unknown log' do
    subject.unknown('message')
    rewind_io
    expect(first_io.read).to match('message')
    expect(second_io.read).to match('message')
  end

  context 'change log level' do
    %w[debug info warn error fatal].each do |level|
      it "set log level to #{level}" do
        subject.send("#{level}!".to_sym)
        expect(subject.send("#{level}?")).to eq true
      end
    end
  end

  context 'log tags' do
    
    let(:test_tag) { 'test_tag' }

    it 'tag without block' do
      tagged_logger = subject.tagged(test_tag)
      tagged_logger.warn 'test'
      rewind_io
      expect(first_io.read).to match(test_tag)
      expect(second_io.read).to match(test_tag)
      clear_io

      subject.warn 'test'
      rewind_io
      expect(first_io.read).not_to match(test_tag)
      expect(second_io.read).not_to match(test_tag)
    end


    it 'tag with block' do
      subject.level = 'debug'
      subject.tagged(test_tag) do |logger|
        logger.debug 'test'
        rewind_io
        expect(first_io.read).to match(test_tag)
        expect(second_io.read).to match(test_tag)
      end
      clear_io

      subject.debug 'test'
      rewind_io
      expect(first_io.read).not_to match(test_tag)
      expect(second_io.read).not_to match(test_tag)
    end

  end

end
