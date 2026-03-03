require 'spec_helper'

RSpec.describe BBK::Utils::Cli::Docs::Builder do
  let(:bbk_config) do
    {
      DATABASE_URL: { env: 'DATABASE_URL', category: 'database', desc: 'Database connection' },
      REDIS_URL: { env: 'REDIS_URL', category: 'redis', desc: 'Redis connection' },
      LOG_LEVEL: { env: 'LOG_LEVEL', category: 'app', desc: 'Log level' },
      AMQP_URL: { env: 'AMQP_URL', category: nil, desc: 'AMQP connection' },
      UNKNOWN_VAR: { env: 'UNKNOWN_VAR', category: nil, desc: 'Unknown variable' }
    }
  end

  let(:config) do
    {
      categories: {
        database: {
          name: 'Database',
          desc: 'Database settings',
          order: 10,
          patterns: ['DATABASE_']
        },
        redis: {
          name: 'Redis',
          desc: 'Redis settings',
          order: 20,
          patterns: ['REDIS_']
        },
        app: {
          name: 'Application',
          desc: 'App settings',
          order: 30,
          envs: ['LOG_LEVEL']
        }
      }
    }
  end

  let(:instance) { described_class.new(bbk_config, config) }

  describe '#initialize' do
    it 'stores bbk config' do
      expect(instance.instance_variable_get(:@bbk)).to eq(bbk_config)
    end

    it 'stores config' do
      expect(instance.instance_variable_get(:@config)).to eq(config)
    end

    it 'creates categories from config' do
      cats = instance.instance_variable_get(:@categories)
      expect(cats).to have_key('database')
      expect(cats['database']).to be_a(BBK::Utils::Cli::Category)
    end

    it 'creates default category' do
      cats = instance.instance_variable_get(:@categories)
      expect(cats).to have_key('other')
      expect(cats['other'].name).to eq('Other')
    end

    it 'creates category with correct id conversion' do
      cats = instance.instance_variable_get(:@categories)
      expect(cats['database'].id).to eq('database')
    end
  end

  describe '#run' do
    it 'assigns configs to matching categories' do
      instance.run
      cats = instance.instance_variable_get(:@categories)
      expect(cats['database'].cfgs).to include(bbk_config[:DATABASE_URL])
    end

    it 'assigns configs matched by patterns' do
      instance.run
      cats = instance.instance_variable_get(:@categories)
      expect(cats['redis'].cfgs).to include(bbk_config[:REDIS_URL])
    end

    it 'assigns configs matched by envs' do
      instance.run
      cats = instance.instance_variable_get(:@categories)
      expect(cats['app'].cfgs).to include(bbk_config[:LOG_LEVEL])
    end

    it 'assigns configs without category to default' do
      instance.run
      cats = instance.instance_variable_get(:@categories)
      expect(cats['other'].cfgs).to include(bbk_config[:AMQP_URL])
      expect(cats['other'].cfgs).to include(bbk_config[:UNKNOWN_VAR])
    end

    it 'sorts configs within category by env name' do
      bbk_config[:TEST_VAR] = { env: 'TEST_VAR', category: 'app', desc: 'Test' }
      instance.run
      cats = instance.instance_variable_get(:@categories)
      expected_order = [bbk_config[:LOG_LEVEL], bbk_config[:TEST_VAR]]
      expect(cats['app'].cfgs).to eq(expected_order)
    end

    it 'sorts categories by order and id' do
      instance.run
      sorted = instance.instance_variable_get(:@sorted)
      expect(sorted[0].id).to eq('database')
      expect(sorted[1].id).to eq('redis')
      expect(sorted[2].id).to eq('app')
    end

    it 'returns self' do
      result = instance.run
      expect(result).to eq(instance)
    end
  end

  describe '#as_json' do
    before do
      instance.run
    end

    it 'returns hash with category ids as keys' do
      json = instance.as_json
      expect(json.keys).to include('database', 'redis', 'app', 'other')
    end

    it 'returns category data as values' do
      json = instance.as_json
      expect(json['database']).to be_a(Hash)
      expect(json['database']).to have_key('id')
      expect(json['database']).to have_key('cfgs')
    end

    it 'includes all categories' do
      json = instance.as_json
      expect(json.size).to eq(4)
    end
  end

  describe '#to_json' do
    before do
      instance.run
    end

    it 'returns valid JSON string' do
      json_str = instance.to_json
      expect { JSON.parse(json_str) }.not_to raise_error
    end

    it 'includes category data' do
      json_str = instance.to_json
      json = JSON.parse(json_str)
      expect(json).to have_key('database')
    end
  end

  describe '#to_markdown' do
    before do
      instance.run
    end

    it 'returns markdown string' do
      md = instance.to_markdown
      expect(md).to be_a(String)
    end

    it 'includes category headers' do
      md = instance.to_markdown
      expect(md).to include('database')
      expect(md).to include('redis')
    end

    it 'skips empty categories' do
      builder = described_class.new({}, config)
      builder.run
      md = builder.to_markdown
      expect(md.strip).to be_empty
    end
  end
end

RSpec.describe BBK::Utils::Cli::Category do
  let(:valid_params) do
    {
      id: 'test_id',
      name: 'Test Name',
      desc: 'Test description',
      order: 10,
      patterns: ['TEST_'],
      envs: ['SPECIFIC_VAR']
    }
  end

  describe '#initialize' do
    it 'requires id' do
      params = valid_params.except(:id)
      expect { described_class.new(**params) }.not_to raise_error
    end

    it 'converts id to string' do
      category = described_class.new(id: :test_id)
      expect(category.id).to be_a(String)
      expect(category.id).to eq('test_id')
    end

    it 'defaults name to empty string if not provided' do
      category = described_class.new(id: 'test_id')
      expect(category.name).to eq('')
    end

    it 'sets name to provided value' do
      category = described_class.new(**valid_params)
      expect(category.name).to eq('Test Name')
    end

    it 'defaults name to nil then string' do
      category = described_class.new(id: 'test', name: nil)
      expect(category.name).to be_a(String)
    end

    it 'converts desc to string' do
      category = described_class.new(id: 'test', desc: 123)
      expect(category.desc).to eq('123')
    end

    it 'defaults patterns to empty array' do
      category = described_class.new(id: 'test')
      expect(category.patterns).to eq([])
    end

    it 'defaults envs to empty array' do
      category = described_class.new(id: 'test')
      expect(category.envs).to eq([])
    end

    it 'defaults order to Infinity' do
      category = described_class.new(id: 'test')
      expect(category.order).to eq(Float::INFINITY)
    end

    it 'defaults cfgs to empty array' do
      category = described_class.new(id: 'test')
      expect(category.cfgs).to eq([])
    end

    it 'sets all provided values' do
      category = described_class.new(**valid_params)
      expect(category.id).to eq('test_id')
      expect(category.name).to eq('Test Name')
      expect(category.desc).to eq('Test description')
      expect(category.order).to eq(10)
      expect(category.patterns).to eq(['TEST_'])
      expect(category.envs).to eq(['SPECIFIC_VAR'])
    end
  end

  describe '#match?' do
    let(:category) { described_class.new(**valid_params) }

    context 'with exact env match' do
      it 'returns true when env name matches exactly' do
        expect(category.match?('SPECIFIC_VAR')).to be true
      end

      it 'returns false when env name does not match' do
        expect(category.match?('OTHER_VAR')).to be false
      end

      it 'strips whitespace from env name' do
        expect(category.match?(' SPECIFIC_VAR ')).to be true
      end
    end

    context 'with pattern match' do
      it 'returns true when env name starts with pattern' do
        expect(category.match?('TEST_VAR')).to be true
      end

      it 'returns false when env name does not start with pattern' do
        expect(category.match?('OTHER_VAR')).to be false
      end

      it 'strips whitespace from env name' do
        expect(category.match?(' TEST_VAR ')).to be true
      end

      it 'works with multiple patterns' do
        category = described_class.new(id: 'test', patterns: ['TEST_', 'OTHER_'])
        expect(category.match?('TEST_VAR')).to be true
        expect(category.match?('OTHER_VAR')).to be true
      end
    end

    context 'with no patterns or envs' do
      it 'returns false' do
        category = described_class.new(id: 'test')
        expect(category.match?('ANY_VAR')).to be false
      end
    end
  end

  describe '#add' do
    let(:category) { described_class.new(id: 'test') }
    let(:cfg1) { { env: 'A_VAR', desc: 'First' } }
    let(:cfg2) { { env: 'B_VAR', desc: 'Second' } }
    let(:cfg3) { { env: 'C_VAR', desc: 'Third' } }

    it 'adds config to cfgs array' do
      category.add(cfg1)
      expect(category.cfgs).to include(cfg1)
    end

    it 'sorts configs by env name' do
      category.add(cfg2)
      category.add(cfg1)
      category.add(cfg3)
      expect(category.cfgs).to eq([cfg1, cfg2, cfg3])
    end

    it 'returns self' do
      result = category.add(cfg1)
      expect(result).to eq(category)
    end

    it 'handles duplicate configs' do
      category.add(cfg1)
      category.add(cfg1)
      expect(category.cfgs.size).to eq(2)
    end

    it 'sorts correctly with multiple adds' do
      cfgs = [
        { env: 'Z_VAR', desc: 'Z' },
        { env: 'A_VAR', desc: 'A' },
        { env: 'M_VAR', desc: 'M' }
      ]
      cfgs.each { |cfg| category.add(cfg) }
      expect(category.cfgs.map { |c| c[:env] }).to eq(['A_VAR', 'M_VAR', 'Z_VAR'])
    end
  end

  describe 'as_json delegation' do
    it 'includes id in json' do
      category = described_class.new(id: 'test')
      expect(category.as_json).to have_key('id')
    end

    it 'includes name in json' do
      category = described_class.new(id: 'test', name: 'Test')
      expect(category.as_json).to have_key('name')
    end

    it 'includes desc in json' do
      category = described_class.new(id: 'test', desc: 'Description')
      expect(category.as_json).to have_key('desc')
    end

    it 'includes order in json' do
      category = described_class.new(id: 'test', order: 10)
      expect(category.as_json).to have_key('order')
    end

    it 'includes patterns in json' do
      category = described_class.new(id: 'test', patterns: ['TEST_'])
      expect(category.as_json).to have_key('patterns')
    end

    it 'includes envs in json' do
      category = described_class.new(id: 'test', envs: ['VAR'])
      expect(category.as_json).to have_key('envs')
    end

    it 'includes cfgs in json' do
      category = described_class.new(id: 'test')
      cfg = { 'env' => 'TEST', 'desc' => 'Test' }
      category.add(cfg)
      expect(category.as_json).to have_key('cfgs')
      expect(category.as_json['cfgs']).to include(cfg)
    end
  end
end
