require 'tmpdir'

RSpec.describe BBK::Utils::Config do
  let(:config) { described_class.new }

  around do |example|
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
        arity = described_class.new.method(method).parameters.select {|k, _v| k == :req }.count
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

    it 'blank default value' do
      config.optional('OPTIONAL', default: '')
      config.run!({})
      expect(config['OPTIONAL']).to eq ''
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
      config.run!({ 'KEY' => value })
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
        'REQUIRED_VAR'       => 'req_val1',
        'REQUIRED_VAR_DESC'  => 'req_val_desc1',

        'OPTIONAL_VAR_DESC'  => 'opt_val_desc1',
        'OPTIONAL_VAR2_DESC' => 'opt_val_desc2',

        'FILE1'              => 'content1',
        'FILE2'              => 'content2'
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

  describe '#fetch' do
    before do
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

  describe 'subconfig' do
    
    let(:prefix) { 'service' }
    let(:amqp_prefix) { 'amqp' }
    let(:service_config) { config.subconfig(prefix: prefix) }
    let(:amqp_config) { service_config.subconfig(prefix: amqp_prefix) }
  
    before do
      config.optional('LOG_LEVEL', default: 'trace')
      config.optional('REDIS_URL', default: 'redis://redis:6379')
      config.optional('NAME', default: 'root')
      service_config.optional('LOG_LEVEL', default: 'trace')
      service_config.optional('DATABASE_URL', default: 'postgres://db:5432/test')
      service_config.optional('NAME', default: 'service')
      amqp_config.optional('LOG_LEVEL', default: 'trace') 
      amqp_config.optional('URL', default: 'amqps://mq:5671')
    end
  
    it 'subconfig has parent' do
      expect(service_config.parent).to eq config
      expect(amqp_config.parent).to eq service_config
    end
  
    it 'config is root' do
      expect(config).to be_root
    end
  
    it 'subconfigs is not root' do
      expect(service_config).not_to be_root
      expect(amqp_config).not_to be_root
    end
  
    it 'get values' do
      config.run!({
        'REDIS_URL' => 'redis://localhost:6379',
        'SERVICE_AMQP_URL' => 'amqp://mq:5672',
        'LOG_LEVEL' => 'debug',
        'SERVICE_LOG_LEVEL' => 'info',
        'SERVICE_AMQP_LOG_LEVEL' => 'error'
      })
      expect(config['REDIS_URL']).to eq 'redis://localhost:6379'
      expect(config['SERVICE_DATABASE_URL']).to eq 'postgres://db:5432/test'
      expect(config['SERVICE_AMQP_URL']).to eq 'amqp://mq:5672'
      expect(config['LOG_LEVEL']).to eq 'debug'

      expect(service_config['DATABASE_URL']).to eq 'postgres://db:5432/test'
      expect(service_config['AMQP_URL']).to eq 'amqp://mq:5672'
      expect(service_config['LOG_LEVEL']).to eq 'info'

      expect(amqp_config['URL']).to eq 'amqp://mq:5672'
      expect(amqp_config['LOG_LEVEL']).to eq 'error'
    end
  
    it 'get parent value if not exists in child' do
      config.run!
      expect(amqp_config['DATABASE_URL']).to eq 'postgres://db:5432/test'
      expect(amqp_config['REDIS_URL']).to eq 'redis://redis:6379'
      expect(amqp_config['NAME']).to eq 'service'

      expect(service_config['REDIS_URL']).to eq 'redis://redis:6379'
      expect(service_config['NAME']).to eq 'service'

      expect(config['NAME']).to eq 'root'
    end
  
  end

end

