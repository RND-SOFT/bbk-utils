# frozen_string_literal: true

require 'uri'

module BBK
  module Utils
    module EnvHelper

      DEFAULT_DATABASE_PREFIX = 'DATABASE'

      def self.prepare_database_envs(env, prefix: DEFAULT_DATABASE_PREFIX)
        uri = build_uri_with_defaults(env, prefix: prefix)
        apply_env_from_uri(env, uri, prefix: prefix)
        env
      end

      def self.prepare_mq_envs(env)
        apply_mq_env_from_uri(env, build_mq_uri_with_defaults(env))
        env
      end

      def self.prepare_jaeger_envs(env)
        jaeger_uri = ::URI.parse(env['JAEGER_URL'] || '').tap do |uri|
          uri.scheme = env.fetch('JAEGER_SENDER', uri.scheme) || 'udp'
          uri.hostname = env.fetch('JAEGER_HOST', uri.host) || 'jaeger'
          uri.port = env.fetch('JAEGER_PORT', uri.port) || 6831
        end
        env['JAEGER_URL'] = jaeger_uri.to_s
        env['JAEGER_SENDER'] = jaeger_uri.scheme
        env['JAEGER_HOST'] = jaeger_uri.host
        env['JAEGER_PORT'] = jaeger_uri.port.to_s
        env
      end

      def self.build_uri_with_defaults(env, prefix: DEFAULT_DATABASE_PREFIX)
        ::URI.parse(env[prefixed_key(prefix, 'URL')] || '').tap do |uri|
          uri.scheme    = env.fetch(prefixed_key(prefix, 'ADAPTER'), uri.scheme) || 'postgresql'
          uri.user      = env.fetch(prefixed_key(prefix, 'USER'), uri.user) || 'postgres'
          uri.password  = env.fetch(prefixed_key(prefix, 'PASS'),    uri.password)
          uri.hostname  = env.fetch(prefixed_key(prefix, 'HOST'),    uri.hostname) || 'db'
          uri.port      = env.fetch(prefixed_key(prefix, 'PORT'),    uri.port) || 5432

          name = env.fetch(prefixed_key(prefix, 'NAME'), uri.path) || ''
          name = "/#{name}" unless name.start_with?('/')
          uri.path = name

          if uri.query
            params = URI.decode_www_form(uri.query).to_h
            params['pool'] = env.fetch(prefixed_key(prefix, 'POOL'), params['pool'])
            uri.query = URI.encode_www_form(params)
          end
        end
      end

      def self.apply_env_from_uri(env, uri, prefix: DEFAULT_DATABASE_PREFIX)
        env[prefixed_key(prefix, 'URL')] = uri.to_s
        env[prefixed_key(prefix, 'ADAPTER')] = uri.scheme
        env[prefixed_key(prefix, 'USER')] = uri.user
        env[prefixed_key(prefix, 'PASS')] = uri.password
        env[prefixed_key(prefix, 'HOST')] = uri.hostname
        env[prefixed_key(prefix, 'PORT')] = uri.port.to_s
        env[prefixed_key(prefix, 'NAME')] = uri.path[1..-1]

        if uri.query
          params = URI.decode_www_form(uri.query).to_h
          env[prefixed_key(prefix, 'POOL')] = params['pool']
        end
      end

      def self.build_mq_uri_with_defaults(env)
        # Only first MQ_URL selected as template if any
        url = [env.fetch('MQ_URL', '').split(/[;|]/)].flatten.select(&:present?).first || ''

        # all hosts if form of list fills url template
        hosts = [env.fetch('MQ_HOST',
                           URI.parse(url).hostname || 'mq').split(/[;|]/)].flatten.select(&:present?).uniq

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


      def self.prefixed_key(prefix, name)
        [prefix, name].select(&:present?).join('_')
      end

    end
  end
end

