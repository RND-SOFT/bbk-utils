require 'mock_redis'

RSpec.describe Aggredator::SharedStore do
  let(:value) { SecureRandom.hex(8) }
  let(:newvalue) { SecureRandom.hex(8) }

  subject do
    described_class.new(redis, 'test_key') { value }
  end

  describe 'without redis' do
    let(:redis) { 'invalid.redis.domain' }

    it "can't write value" do
      expect(subject.write(newvalue)).to be_falsey
    end

    it "can't change value" do
      expect { subject.write(newvalue) }.not_to change { subject.fetch }
    end

    it "can't clear value" do
      expect { subject.clear }.not_to change { subject.fetch }
    end

    it 'fetch' do
      expect(subject.fetch).to eq value
    end
  end

  describe 'with redis' do
    # monkeypatch
    class MockRedis
      def with
        yield(self)
      end
    end

    let(:redis) { MockRedis.new }

    it 'can write value' do
      expect(subject.write(newvalue)).to be_truthy
    end

    it 'can change value' do
      expect { subject.write(newvalue) }.to change { subject.fetch }.from(value).to(newvalue)
    end

    it 'can clear value' do
      expect(subject.write(newvalue)).to be_truthy
      expect { subject.clear }.to change { subject.fetch }.from(newvalue).to(value)
    end

    it 'fetch' do
      expect(subject.fetch).to eq value
    end
  end
end
