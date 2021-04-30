require 'tmpdir'

RSpec.describe Aggredator::Config do
  let(:config) { described_class.new }

  around :each do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        example.run
      end
    end
  end

  describe 'delegating' do
    it 'instance' do
      expect(described_class.instance).to be_a(described_class)
    end

    %i[map require optional run! \[\] \[\]= content to_s].each do |method|
      it method.to_s do
        arity = described_class.new.method(method).parameters.select { |k, _v| k == :req }.count
        args = arity.times.map(&:to_s)
        expect(described_class.instance).to receive(method)
        described_class.send(method, *args)
      end
    end
  end

  describe 'File mapping' do
    let(:file) { Faker::File.file_name(dir: 'some/path') }
    let(:content) { Faker::Ancient.hero }

    it 'optional file can be skipped' do
      config.map('FILE_ENV', file, required: false)
      env = {}

      expect do
        config.run!(env)
      end.not_to raise_error
    end

    it 'required file cannot be skipped' do
      config.map('FILE_ENV', file, required: true)
      env = {}

      expect do
        config.run!(env)
      end.to raise_error(RuntimeError)
    end

    it 'File must be mapped' do
      config.map('FILE_ENV', file)
      env = { 'FILE_ENV' => content }
      config.run!(env)

      expect(File.read(file)).to eq content
    end

    it 'path can be accessed by []' do
      config.map('FILE_ENV', file)
      env = { 'FILE_ENV' => content }

      expect(config['FILE_ENV']).not_to eq file
      config.run!(env)
      expect(config['FILE_ENV']).to eq file
    end

    it 'content can be accessed by content' do
      config.map('FILE_ENV', file)
      env = { 'FILE_ENV' => content }
      config.run!(env)
      expect(config.content('FILE_ENV')).to eq content
    end
  end

  describe 'Env parsing' do
    let(:value) { Faker::Ancient.hero }

    it 'optional variable' do
      config.optional('OPTIONAL')
      env = {}

      expect do
        config.run!(env)
      end.not_to raise_error
    end

    it 'required variable must raise' do
      config.require('REQUIRED')
      env = {}

      expect do
        config.run!(env)
      end.to raise_error(RuntimeError)
    end

    it 'variable can be accessed by []' do
      config.require('REQUIRED')
      env = { 'REQUIRED' => value }

      expect(config['REQUIRED']).not_to eq value
      config.run!(env)
      expect(config['REQUIRED']).to eq value
    end

    it 'variable can be updated by []=' do
      config.require('REQUIRED')
      env = { 'REQUIRED' => value }

      config.run!(env)
      expect(config['REQUIRED']).to eq value
      config['REQUIRED'] = 777
      expect(config['REQUIRED']).to eq 777
    end

    it 'default value' do
      config.optional('OPTIONAL', default: 'def1')
      env = {}

      config.run!(env)
      expect(config['OPTIONAL']).to eq 'def1'
    end

    it 'default value can be overriden' do
      config.optional('OPTIONAL', default: 'def1')
      env = { 'OPTIONAL' => 'value2' }

      config.run!(env)
      expect(config['OPTIONAL']).to eq 'value2'
    end

    it 'check specific env key' do
      config.optional('OPTIONAL', key: 'key')
      env = { 'KEY' => 'value' }
      config.run!(env)
      expect(config['OPTIONAL']).to eq 'value'
    end

    it 'default false value' do
      config.optional('KEY', default: false, bool: true)
      config.run!({})
      expect(config['KEY']).to eq false
    end

    it 'call initialize from passed type' do
      cls = Class.new do
        attr_reader :value
        def initialize(value)
          @value = value
        end
      end
      config.optional('KEY', type: cls)
      value = SecureRandom.hex
      config.run!({'KEY' => value})
      expect(config['KEY']).to be_a(cls)
      expect(config['KEY'].value).to eq value
    end

  end

  describe 'Example' do
    def sort_output(string)
      string.strip.split("\n").map(&:strip).sort.join("\n")
    end

    it 'complete' do
      config.require('REQUIRED_VAR')
      config.require('REQUIRED_VAR_DESC', desc: 'desc1')

      config.optional('OPTIONAL_VAR')
      config.optional('OPTIONAL_VAR_DESC', desc: 'desc2')

      config.optional('OPTIONAL_VAR2', default: 'default1')
      config.optional('OPTIONAL_VAR2_DESC', default: 'default1', desc: 'desc3')

      config.map('FILE1', 'some/folder/file.1')
      config.map('FILE2', 'some/folder/file.2', desc: 'file2 description')

      env = {
        'REQUIRED_VAR' => 'req_val1',
        'REQUIRED_VAR_DESC' => 'req_val_desc1',

        'OPTIONAL_VAR_DESC' => 'opt_val_desc1',
        'OPTIONAL_VAR2_DESC' => 'opt_val_desc2',

        'FILE1' => 'content1',
        'FILE2' => 'content2'
      }

      expect do
        config.run!(env)
      end.not_to raise_error

      result = %{
Environment variables:
   File <FILE1>
      -> "some/folder/file.1"
   File <FILE2>                                    file2 description
      -> "some/folder/file.2"
   <REQUIRED_VAR>
      -> "req_val1"
   <REQUIRED_VAR_DESC>                             desc1
      -> "req_val_desc1"
   [OPTIONAL_VAR]
      -> nil
   [OPTIONAL_VAR_DESC]                             desc2
      -> "opt_val_desc1"
   [OPTIONAL_VAR2] (=default1)
      -> "default1"
   [OPTIONAL_VAR2_DESC] (=default1)                desc3
      -> "opt_val_desc2"
}

      expect(sort_output(config.to_s)).to eq(sort_output(result))
    end
  end

  context '#fetch' do
    before(:each) do
      config.optional('TEST', default: :default)
    end

    it 'get value from not builded config' do
      expect(config.fetch('TEST', :value)).to eq :value
    end

    it 'get value from builded config' do
      config.run!
      expect(config.fetch('TEST')).to eq :default
    end

    it 'get default' do
      expect(config.fetch('invalid key', :value)).to eq :value
    end
  end
end
