# frozen_string_literal: true

module Aggredator
  module EnvHelper
    def self.prepare_database_envs(env)
      uri = build_uri_with_defaults(env)
      apply_env_from_uri(env, uri)
      env
    end

    def self.build_uri_with_defaults(env)
      URI.parse(env['DATABASE_URL'] || '').tap do |uri|
        uri.scheme    = env.fetch('DATABASE_ADAPTER', uri.scheme) || 'postgresql'
        uri.user      = env.fetch('DATABASE_USER',    uri.user) || 'postgres'
        uri.password  = env.fetch('DATABASE_PASS',    uri.password)
        uri.hostname  = env.fetch('DATABASE_HOST',    uri.hostname) || 'db'
        uri.port      = env.fetch('DATABASE_PORT',    uri.port) || 5432

        name = env.fetch('DATABASE_NAME',    uri.path) || ''
        name = "/#{name}" unless name.start_with?("/")
        uri.path      = name
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
  end
end
