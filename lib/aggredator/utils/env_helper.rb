# frozen_string_literal: true
require 'uri'

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
      ::URI.parse(env['DATABASE_URL'] || '').tap do |uri|
        uri.scheme    = env.fetch('DATABASE_ADAPTER', uri.scheme) || 'postgresql'
        uri.user      = env.fetch('DATABASE_USER',    uri.user) || 'postgres'
        uri.password  = env.fetch('DATABASE_PASS',    uri.password)
        uri.hostname  = env.fetch('DATABASE_HOST',    uri.hostname) || 'db'
        uri.port      = env.fetch('DATABASE_PORT',    uri.port) || 5432

        name = env.fetch('DATABASE_NAME', uri.path) || ''
        name = "/#{name}" unless name.start_with?('/')
        uri.path = name

        if uri.query
          params = URI.decode_www_form(uri.query).to_h
          params['pool'] = env.fetch('DATABASE_POOL', params['pool'])
          uri.query = URI.encode_www_form(params)
        end

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

      if uri.query
        params = URI.decode_www_form(uri.query).to_h
        env['DATABASE_POOL'] = params['pool']
      end

    end

    def self.build_mq_uri_with_defaults(env)
      # Only first MQ_URL selected as template if any
      url = [env.fetch('MQ_URL', '').split(/[;\|]/)].flatten.select(&:present?).first || ''

      # all hosts if form of list fills url template
      hosts = [env.fetch('MQ_HOST', URI.parse(url).hostname || 'mq').split(/[;\|]/)].flatten.select(&:present?).uniq

      hosts.map do |host|
        URI.parse(url).tap do |uri|
          uri.scheme   = uri.scheme || 'amqps'
          uri.hostname = host
          uri.port     = env.fetch('MQ_PORT', uri.port) || 5671
          uri.user     = env.fetch('MQ_USER', uri.user)
          uri.password = env.fetch('MQ_PASS', uri.password)

          vhost = [env.fetch('MQ_VHOST', uri.path), '/'].find(&:present?)
          vhost = "/#{vhost}" unless vhost.start_with?('/')

          uri.path = vhost
        end
      end
    end

    def self.apply_mq_env_from_uri(env, uris)
      uri = uris.first

      env['MQ_URL']   = uris.map(&:to_s).join(';')
      env['MQ_HOST']  = uris.map(&:hostname).join(';')
      env['MQ_PORT']  = uri.port.to_s
      env['MQ_PASS']  = uri.password
      env['MQ_USER']  = uri.user
      vhost = if uri.path == '/'
                uri.path
              else
                uri.path.gsub(%r{\A/}, '')
              end
      env['MQ_VHOST'] = vhost
    end
  end
end
