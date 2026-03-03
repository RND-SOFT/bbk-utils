require 'spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe BBK::Utils::Cli::Docs do
  let(:config_content) do
    {
      categories: {
        test_category: {
          name: 'Test Category',
          desc: 'Test description',
          order: 10,
          patterns: ['TEST_'],
          envs: ['SPECIFIC_VAR']
        }
      }
    }
  end

  let(:bbk_config) do
    {
      'TEST_VAR' => {
        env: 'TEST_VAR',
        desc: 'Test variable',
        default: 'test',
        category: 'test_category',
        _class: 'String',
        required: false
      },
      'OTHER_VAR' => {
        env: 'OTHER_VAR',
        desc: 'Other variable',
        default: 'other',
        _class: 'String',
        required: false
      }
    }
  end

  let(:argv) { [] }
  let(:instance) { described_class.new(argv) }

  before do
    allow(BBK::Utils::Config).to receive(:instance).and_return(double('Config').as_null_object)
    allow(BBK::Utils::Config.instance).to receive(:name).and_return(nil)
    allow(BBK::Utils::Config.instance).to receive(:as_json).and_return(bbk_config)
    allow(BBK::Utils::Config.instance).to receive(:send).with(:store_with_subconfigs).and_return({})
    allow(BBK::Utils::Config.instance).to receive(:send).with(:store).and_return({})
  end

  describe '#initialize' do
    it 'stores argv' do
      expect(instance.instance_variable_get(:@argv)).to eq(argv)
    end
  end

  describe '#parse!' do
    context 'with default options' do
    it 'returns default config path' do
      options = instance.parse!([])
      expect(options[:config]).to end_with('./.bbkdocs.yml')
    end

    it 'returns default output path' do
      options = instance.parse!([])
      expect(options[:output]).to end_with('./bbkdocs.md')
    end

    it 'returns default categories path' do
      options = instance.parse!([])
      expect(options[:categories]).to end_with('./bbkdocs.json')
    end
    end

    context 'with custom config option' do
      it 'sets custom config path' do
        options = instance.parse!(%w[-c /custom/config.yml])
        expect(options[:config]).to eq('/custom/config.yml')
      end

      it 'sets custom config path with long option' do
        options = instance.parse!(%w[--config /custom/config.yml])
        expect(options[:config]).to eq('/custom/config.yml')
      end

    it 'converts relative path to absolute' do
      options = instance.parse!(%w[-c custom/config.yml])
      expect(options[:config]).to end_with('custom/config.yml')
    end
    end

    context 'with custom output option' do
      it 'sets custom output path' do
        options = instance.parse!(%w[-o /custom/output.md])
        expect(options[:output]).to eq('/custom/output.md')
      end

      it 'sets custom output path with long option' do
        options = instance.parse!(%w[--output /custom/output.md])
        expect(options[:output]).to eq('/custom/output.md')
      end
    end

    context 'with custom categories option' do
      it 'sets custom categories path' do
        options = instance.parse!(%w[-g /custom/categories.json])
        expect(options[:categories]).to eq('/custom/categories.json')
      end

      it 'sets custom categories path with long option' do
        options = instance.parse!(%w[--categories /custom/categories.json])
        expect(options[:categories]).to eq('/custom/categories.json')
      end
    end

    context 'with multiple options' do
      it 'parses all options correctly' do
        options = instance.parse!(%w[-c config.yml -o output.md -g categories.json])
        expect(options[:config]).to end_with('config.yml')
        expect(options[:output]).to end_with('output.md')
        expect(options[:categories]).to end_with('categories.json')
      end
    end
  end

  describe '#load_configuration' do
    let(:default_config_file) { File.expand_path('../../../../lib/bbk/utils/cli/bbkdocs.yml', __dir__) }

    it 'loads configuration from file' do
      config = instance.load_configuration(default_config_file)
      expect(config).to be_a(Hash)
      expect(config).to have_key(:categories)
    end

    it 'symbolizes keys' do
      config = instance.load_configuration(default_config_file)
      expect(config.keys).to all(be_a(Symbol))
      expect(config[:categories].keys).to all(be_a(Symbol))
    end

    it 'merges multiple configuration files' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { test1: { key: 'value1' } }.to_yaml)
        File.write(file2, { test2: { key: 'value2' } }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config).to have_key(:test1)
        expect(config).to have_key(:test2)
      end
    end

    it 'deep merges hashes' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { test: { key1: 'value1' } }.to_yaml)
        File.write(file2, { test: { key2: 'value2' } }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:test]).to have_key(:key1)
        expect(config[:test]).to have_key(:key2)
      end
    end

    it 'merges arrays for patterns key' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { patterns: ['pattern1'] }.to_yaml)
        File.write(file2, { patterns: ['pattern2'] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:patterns]).to include('pattern1')
        expect(config[:patterns]).to include('pattern2')
      end
    end

    it 'merges arrays for envs key' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { envs: ['env1'] }.to_yaml)
        File.write(file2, { envs: ['env2'] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:envs]).to include('env1')
        expect(config[:envs]).to include('env2')
      end
    end

    it 'replaces arrays for other keys' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { other: ['value1'] }.to_yaml)
        File.write(file2, { other: ['value2'] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:other]).to eq(['value2'])
      end
    end

    it 'handles nil values in hash merge' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { test: { key1: nil } }.to_yaml)
        File.write(file2, { test: { key2: 'value2' } }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:test]).to have_key(:key1)
        expect(config[:test]).to have_key(:key2)
      end
    end

    it 'compacts array values' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { patterns: ['pattern1', nil] }.to_yaml)
        File.write(file2, { patterns: ['pattern2', nil] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:patterns]).to eq(['pattern1', 'pattern2'])
      end
    end

    it 'strips whitespace from array values' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { patterns: [' pattern1 '] }.to_yaml)
        File.write(file2, { patterns: [' pattern2 '] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:patterns]).to eq(['pattern1', 'pattern2'])
      end
    end

    it 'converts array values to strings' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'config1.yml')
        file2 = File.join(dir, 'config2.yml')

        File.write(file1, { patterns: [:pattern1] }.to_yaml)
        File.write(file2, { patterns: [:pattern2] }.to_yaml)

        config = instance.load_configuration(file1, file2)
        expect(config[:patterns]).to eq(['pattern1', 'pattern2'])
      end
    end
  end

  describe '#extract_bbk_config' do
    it 'returns config with symbolized keys' do
      result = instance.extract_bbk_config
      expect(result.keys).to all(be_a(Symbol))
    end

    it 'includes all bbk config entries' do
      result = instance.extract_bbk_config
      expect(result).to have_key(:TEST_VAR)
      expect(result).to have_key(:OTHER_VAR)
    end

    context 'when Config.instance has a name' do
      before do
        allow(BBK::Utils::Config.instance).to receive(:name).and_return('named_config')
      end

      it 'extracts named config' do
        allow(BBK::Utils::Config.instance).to receive(:as_json).and_return({
          'named_config' => bbk_config,
          'other_config' => { 'KEY' => 'value' }
        })
        result = instance.extract_bbk_config
        expect(result).to have_key(:TEST_VAR)
      end
    end

    context 'with store_with_subconfigs containing Fugit::Duration' do
      let(:fugit_class) { double('FugitDuration', to_s: 'Fugit::Duration', class: nil) }
      let(:fugit_duration) { double('Duration', original: '60s', class: fugit_class) }

      before do
        allow(BBK::Utils::Config.instance).to receive(:send).with(:store_with_subconfigs).and_return({
          'DURATION_VAR' => { default: fugit_duration }
        })
        bbk_config['DURATION_VAR'] = {
          env: 'DURATION_VAR',
          desc: 'Duration variable',
          default: fugit_duration,
          _class: nil,
          required: false
        }
      end

      it 'sets original value for Fugit::Duration' do
        result = instance.extract_bbk_config
        expect(result[:DURATION_VAR][:default]).to eq('60s')
      end
    end

    context 'with store_with_subconfigs containing non-nil defaults' do
      before do
        allow(BBK::Utils::Config.instance).to receive(:send).with(:store_with_subconfigs).and_return({
          'STRING_VAR' => { default: 'test_string' }
        })
        bbk_config['STRING_VAR'] = {
          env: 'STRING_VAR',
          desc: 'String variable',
          default: 'test_string',
          required: false
        }
      end

      it 'sets _class for non-nil defaults' do
        result = instance.extract_bbk_config
        expect(result[:STRING_VAR][:_class]).to eq('String')
      end
    end

    context 'with nil defaults' do
      before do
        allow(BBK::Utils::Config.instance).to receive(:send).with(:store_with_subconfigs).and_return({
          'NIL_VAR' => { default: nil }
        })
        bbk_config['NIL_VAR'] = {
          env: 'NIL_VAR',
          desc: 'Nil variable',
          default: nil,
          required: false
        }
      end

      it 'does not set _class for nil defaults' do
        result = instance.extract_bbk_config
        expect(result[:NIL_VAR]).not_to have_key(:_class)
      end
    end
  end

  describe '#run' do
    let(:config_file) { File.join(__dir__, '../../../lib/bbk/utils/cli/bbkdocs.yml') }
    let(:argv) { %w[-c #{config_file}] }

    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir dir do
          example.run
        end
      end
    end

    before do
      allow(JSON).to receive(:pretty_generate).and_return('{}')
      allow(instance).to receive(:load_configuration).and_return(config_content.deep_dup.deep_symbolize_keys!)
    end

    it 'creates output directory' do
      expect { instance.run(%w[-o /tmp/test/output.md]) }.not_to raise_error
    end

    it 'creates categories directory' do
      expect { instance.run(%w[-g /tmp/test/categories.json]) }.not_to raise_error
    end

    it 'writes JSON output to file' do
      output_path = File.join(Dir.pwd, 'test.json')
      instance.run(['-g', output_path])
      expect(File.exist?(output_path)).to be true
      expect(JSON.parse(File.read(output_path))).to be_a(Hash)
    end

    it 'writes Markdown output to file' do
      output_path = File.join(Dir.pwd, 'test.md')
      instance.run(['-o', output_path])
      expect(File.exist?(output_path)).to be true
      expect(File.read(output_path)).not_to be_empty
    end

    it 'initializes Builder with correct arguments' do
      expect(BBK::Utils::Cli::Docs::Builder).to receive(:new).with(instance.send(:extract_bbk_config), anything).and_call_original
      instance.run
    end

    it 'calls run on builder' do
      builder_double = double('Builder', run: nil, as_json: {}, to_markdown: '')
      allow(BBK::Utils::Cli::Docs::Builder).to receive(:new).and_return(builder_double)
      expect(builder_double).to receive(:run)
      instance.run
    end

    it 'prints success message for JSON' do
      expect { instance.run(%w[-g test.json]) }.to output(/Documentation JSON saved to:/).to_stdout
    end

    it 'prints success message for Markdown' do
      expect { instance.run(%w[-o test.md]) }.to output(/Documentation MArkdown saved to:/).to_stdout
    end
  end
end
