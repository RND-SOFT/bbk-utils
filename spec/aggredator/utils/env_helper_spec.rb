# frozen_string_literal: true

RSpec.describe Aggredator::EnvHelper do
  ENV_EXAMPLES = [
    { url: 'postgresql://user:pass@db:1234/dbname?pool=15', variants: [
      { env: {}, result: { user: 'user', pass: 'pass', host: 'db', port: '1234', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_ADAPTER' => 'mysql' }, result: { user: 'user', pass: 'pass', host: 'db', port: '1234', name: 'dbname', adapter: 'mysql' } },
      { env: { 'DATABASE_USER' => 'u1' },       result: { user: 'u1',   pass: 'pass', host: 'db', port: '1234', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_PASS' => 'p1' },       result: { user: 'user', pass: 'p1',   host: 'db', port: '1234', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_PASS' => nil },        result: { user: 'user', pass: nil,    host: 'db', port: '1234', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_HOST' => 'h1' },       result: { user: 'user', pass: 'pass', host: 'h1', port: '1234', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_PORT' => '4321' },     result: { user: 'user', pass: 'pass', host: 'db', port: '4321', name: 'dbname', adapter: 'postgresql' } },
      { env: { 'DATABASE_NAME' => 'tmp' },      result: { user: 'user', pass: 'pass', host: 'db', port: '1234', name: 'tmp',    adapter: 'postgresql' } }
    ] },
    { url: nil, variants: [
      { env: {}, result: { user: 'postgres', pass: nil, host: 'db', port: '5432', name: '', adapter: 'postgresql' } },
      { env: { 'DATABASE_ADAPTER' => 'mysql' }, result: { user: 'postgres', pass: nil,  host: 'db', port: '5432', name: '', adapter: 'mysql' } },
      { env: { 'DATABASE_USER' => 'u1' },       result: { user: 'u1',       pass: nil,  host: 'db', port: '5432', name: '', adapter: 'postgresql' } },
      { env: { 'DATABASE_PASS' => 'p1' },       result: { user: 'postgres', pass: 'p1', host: 'db', port: '5432', name: '', adapter: 'postgresql' } },
      { env: { 'DATABASE_HOST' => 'h1' },       result: { user: 'postgres', pass: nil,  host: 'h1', port: '5432', name: '', adapter: 'postgresql' } },
      { env: { 'DATABASE_PORT' => '4321' },     result: { user: 'postgres', pass: nil,  host: 'db', port: '4321', name: '', adapter: 'postgresql' } },
      { env: { 'DATABASE_NAME' => 'tmp' },      result: { user: 'postgres', pass: nil,  host: 'db', port: '5432', name: 'tmp',    adapter: 'postgresql' } }
    ] }
  ].freeze

  def match_env(env, result)
    result_env = result.each_with_object({}) do |(k, v), ret|
      ret["DATABASE_#{k}".upcase] = v
    end

    expect(env).to include(result_env)
    uri = URI.parse(env['DATABASE_URL'])
    expect(uri).to have_attributes(scheme: result[:adapter], user: result[:user], password: result[:pass], hostname: result[:host], port: result[:port].to_i, path: "/#{result[:name]}")
  end

  context 'auto examples' do
    ENV_EXAMPLES.each_with_index do |ex, i|
      context "#{i} URL: #{ex[:url]}" do
        let(:url) { ex[:url] }

        ex[:variants].each_with_index do |variant, j|
          it "#{j} #{variant[:env].to_s}" do
            env = variant[:env].merge('DATABASE_URL' => url)
            env = Aggredator::EnvHelper.prepare_database_envs(env)
            match_env(env, variant[:result])
          end
        end
      end
    end
  end
end
