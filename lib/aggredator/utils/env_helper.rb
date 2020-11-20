# frozen_string_literal: true

module Aggredator
  module EnvHelper
    def self.prepare_database_envs(env)
      uri = build_uri_with_defaults(env)
      apply_env_from_uri(env, uri)
      env
    end

    def self.prepare_mq_envs(env)
      apply_mq_env_from_uri(env, build_mq_uri_with_defaults(env))
      env
    end

    def self.build_uri_with_defaults(env)
      URI.parse(env['DATABASE_URL'] || '').tap do |uri|
        uri.scheme    = env.fetch('DATABASE_ADAPTER', uri.scheme) || 'postgresql'
        uri.user      = env.fetch('DATABASE_USER',    uri.user) || 'postgres'
        uri.password  = env.fetch('DATABASE_PASS',    uri.password)
        uri.hostname  = env.fetch('DATABASE_HOST',    uri.hostname) || 'db'
        uri.port      = env.fetch('DATABASE_PORT',    uri.port) || 5432

        name = env.fetch('DATABASE_NAME', uri.path) || ''
        name = "/#{name}" unless name.start_with?('/')
        uri.path = name
      end
    end

    def self.apply_env_from_uri(env, uri)
      env['DATABASE_URL'] = uri.to_s
      env['DATABASE_ADAPTER'] = uri.scheme
      env['DATABASE_USER'] = uri.user
      env['DATABASE_PASS'] = uri.password
      env['DATABASE_HOST'] = uri.hostname
      env['DATABASE_PORT'] = uri.port.to_s
      env['DATABASE_NAME'] = uri.path[1..-1]
    end

    def self.build_mq_uri_with_defaults(env)
      URI.parse(env['MQ_URL'] || '').tap do |uri|
        uri.scheme   = 'amqps'
        uri.hostname = env.fetch('MQ_HOST', uri.hostname) || 'mq'
        uri.port     = env.fetch('MQ_PORT', uri.port) || 5671

        vhost = [env.fetch('MQ_VHOST', uri.path), '/'].find(&:present?)
        vhost = "/#{vhost}" unless vhost.start_with?('/')

        uri.path = vhost
      end
    end

    def self.apply_mq_env_from_uri(env, uri)
      env['MQ_URL']   = uri.to_s
      env['MQ_HOST']  = uri.hostname
      env['MQ_PORT']  = uri.port.to_s
      vhost = if uri.path == '/'
                uri.path
              else
                uri.path.gsub(%r{\A/}, '')
              end
      env['MQ_VHOST'] = vhost
    end
  end
end
