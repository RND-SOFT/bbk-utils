# frozen_string_literal: true

require 'uri'

module BBK
  module Utils
    # Вспомогательный модуль для сборки и нормализации переменных окружения
    # при подключении к внешним сервисам.
    #
    # Предоставляет методы для конструирования URL-подключений из переменных окружения
    # с интеллектуальными значениями по умолчанию и механизмом переопределения.
    # Поддерживает базы данных, очереди сообщений и сервисы трейсинга.
    #
    # @example Базовое использование для конфигурации базы данных
    #   env = {
    #     'DATABASE_URL' => 'postgres://old:pass@oldhost:5432/olddb',
    #     'DATABASE_HOST' => 'newhost',
    #     'DATABASE_NAME' => 'newdb'
    #   }
    #   BBK::Utils::EnvHelper.prepare_database_envs(env)
    #   # => env['DATABASE_URL'] = 'postgres://old:pass@newhost:5432/newdb'
    #   # => env['DATABASE_HOST'] = 'newhost'
    #   # => env['DATABASE_NAME'] = 'newdb'
    #
    # @note Все методы изменяют переданный хэш env in-place и возвращают его
    module EnvHelper

      # @return [String] Префикс по умолчанию для переменных окружения, связанных с базой данных
      DEFAULT_DATABASE_PREFIX = 'DATABASE'

      # Подготавливает переменные окружения для подключения к базе данных.
      #
      # Собирает URL подключения к БД из отдельных переменных окружения или
      # переопределяет компоненты существующего URL. После сборки URL раскладывает
      # его обратно в индивидуальные переменные окружения.
      #
      # Поддерживаемые переменные окружения (с префиксом):
      # - {prefix}_URL - базовый URL (опционально, используется как шаблон)
      # - {prefix}_ADAPTER - адаптер/схема БД (по умолчанию: 'postgresql')
      # - {prefix}_HOST - хост БД (по умолчанию: 'db')
      # - {prefix}_PORT - порт БД (по умолчанию: 5432)
      # - {prefix}_USER - пользователь БД (по умолчанию: 'postgres')
      # - {prefix}_PASS - пароль БД (по умолчанию: nil)
      # - {prefix}_NAME - имя БД/путь
      # - {prefix}_POOL - размер пула соединений. Используется **только если в {prefix}_URL присутствует query-строка** (не обязательно содержащая параметр `pool`). Если query-строки нет, значение игнорируется.
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV (изменяется in-place)
      # @param prefix [String] Префикс для имен переменных окружения
      # @return [Hash{String=>String}, ENV] Тот же объект env (изменён in-place)
      #
      # @example Только с URL
      #   env = { 'DATABASE_URL' => 'postgres://user:pass@host:5432/mydb' }
      #   prepare_database_envs(env)
      #   # => env['DATABASE_HOST'] = 'host', env['DATABASE_PORT'] = '5432', и т.д.
      #
      # @example С URL и переопределениями
      #   env = { 'DATABASE_URL' => 'postgres://user:pass@host:5432/mydb', 'DATABASE_HOST' => 'newhost' }
      #   prepare_database_envs(env)
      #   # => env['DATABASE_URL'] = 'postgres://user:pass@newhost:5432/mydb'
      #
      # @example Только с индивидуальными переменными
      #   env = { 'DATABASE_HOST' => 'myhost', 'DATABASE_NAME' => 'mydb' }
      #   prepare_database_envs(env)
      #   # => env['DATABASE_URL'] = 'postgresql://postgres@myhost:5432/mydb'
      def self.prepare_database_envs(env, prefix: DEFAULT_DATABASE_PREFIX)
        uri = build_uri_with_defaults(env, prefix: prefix)
        apply_env_from_uri(env, uri, prefix: prefix)
        env
      end

      # Подготавливает переменные окружения для подключения к очереди сообщений.
      #
      # Собирает URL для MQ из переменных окружения с поддержкой нескольких хостов (кластер).
      # Хосты могут быть указаны в виде списка, разделенного точкой с запятой или вертикальной чертой,
      # в переменной MQ_HOST.
      #
      # Поддерживаемые переменные окружения:
      # - MQ_URL - базовый URL-шаблон (опционально, используется первый, если несколько)
      # - MQ_HOST - хост(ы), могут быть разделены ';' или '|' (по умолчанию: 'mq')
      # - MQ_PORT - порт (по умолчанию: 5671)
      # - MQ_USER - имя пользователя
      # - MQ_PASS - пароль
      # - MQ_VHOST - виртуальный хост (по умолчанию: '/')
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV (изменяется in-place)
      # @return [Hash{String=>String}, ENV] Тот же объект env (изменён in-place)
      #
      # @example Один хост
      #   env = { 'MQ_HOST' => 'rabbitmq', 'MQ_USER' => 'guest' }
      #   prepare_mq_envs(env)
      #   # => env['MQ_URL'] = 'amqps://guest@rabbitmq:5671/'
      #
      # @example Несколько хостов (кластер)
      #   env = { 'MQ_HOST' => 'mq1;mq2;mq3', 'MQ_USER' => 'guest' }
      #   prepare_mq_envs(env)
      #   # => env['MQ_URL'] = 'amqps://guest@mq1:5671/;amqps://guest@mq2:5671/;amqps://guest@mq3:5671/'
      #   # => env['MQ_HOST'] = 'mq1;mq2;mq3'
      def self.prepare_mq_envs(env)
        apply_mq_env_from_uri(env, build_mq_uri_with_defaults(env))
        env
      end

      # Подготавливает переменные окружения для Jaeger трейсинга.
      #
      # Собирает URL подключения к Jaeger из переменных окружения.
      #
      # Поддерживаемые переменные окружения:
      # - JAEGER_URL - базовый URL (опционально)
      # - JAEGER_SENDER - протокол/схема отправки (по умолчанию: 'udp')
      # - JAEGER_HOST - хост Jaeger агента (по умолчанию: 'jaeger')
      # - JAEGER_PORT - порт Jaeger агента (по умолчанию: 6831)
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV (изменяется in-place)
      # @return [Hash{String=>String}, ENV] Тот же объект env (изменён in-place)
      #
      # @example
      #   env = { 'JAEGER_HOST' => 'jaeger-agent' }
      #   prepare_jaeger_envs(env)
      #   # => env['JAEGER_URL'] = 'udp://jaeger-agent:6831'
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

      # Собирает объект URI из переменных окружения со значениями по умолчанию.
      # При отсутствии {prefix}_URL используется пустой URI (URI.parse('')).
      #
      # @note Приоритет для каждого компонента:
      #   1. Индивидуальная переменная окружения (например, DATABASE_HOST)
      #   2. Компонент из базового URL (например, host из DATABASE_URL)
      #   3. Значение по умолчанию (например, 'db')
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV
      # @param prefix [String] Префикс для имен переменных окружения
      # @return [URI::Generic] Сконструированный объект URI
      # @api private
      def self.build_uri_with_defaults(env, prefix: DEFAULT_DATABASE_PREFIX)
        ::URI.parse(env[prefixed_key(prefix, 'URL')] || '').then do |uri|
          result = uri.clone
          result.scheme    = env.fetch(prefixed_key(prefix, 'ADAPTER'), uri.scheme) || 'postgresql'
          result.hostname  = env.fetch(prefixed_key(prefix, 'HOST'),    uri.hostname) || 'db'
          result.port      = env.fetch(prefixed_key(prefix, 'PORT'),    uri.port) || 5432
          result.user      = env.fetch(prefixed_key(prefix, 'USER'), uri.user) || 'postgres'
          result.password  = env.fetch(prefixed_key(prefix, 'PASS'), uri.password)

          name = env.fetch(prefixed_key(prefix, 'NAME'), uri.path) || ''
          name = "/#{name}" unless name.start_with?('/')
          result.path = name

          if uri.query
            params = URI.decode_www_form(uri.query).to_h
            params['pool'] = env.fetch(prefixed_key(prefix, 'POOL'), params['pool'])
            result.query = URI.encode_www_form(params)
          end
          result
        end
      end

      # Раскладывает URI в индивидуальные переменные окружения.
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV (изменяется in-place)
      # @param uri [URI::Generic] Объект URI для декомпозиции
      # @param prefix [String] Префикс для имен переменных окружения
      # @return [void]
      # @api private
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

      # Собирает объекты URI для MQ из переменных окружения с поддержкой нескольких хостов.
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV
      # @return [Array<URI>] Массив объектов URI (по одному на каждый хост)
      # @api private
      def self.build_mq_uri_with_defaults(env)
        # Только первый MQ_URL выбирается как шаблон, если их несколько
        url = [env.fetch('MQ_URL', '').split(/[;|]/)].flatten.select(&:present?).first || ''

        # Все хосты в виде списка заполняют шаблон URL
        hosts = [env.fetch('MQ_HOST',
                           URI.parse(url).hostname || 'mq').split(/[;|]/)].flatten.select(&:present?).uniq

        hosts.map do |host|
          URI.parse(url).then do |uri|
            result = uri.clone
            result.scheme   = uri.scheme || 'amqps'
            result.hostname = host
            result.port     = env.fetch('MQ_PORT', uri.port) || 5671
            result.user     = env.fetch('MQ_USER', uri.user)
            result.password = env.fetch('MQ_PASS', uri.password)

            vhost = [env.fetch('MQ_VHOST', uri.path), '/'].find(&:present?)
            vhost = "/#{vhost}" unless vhost.start_with?('/')

            result.path = vhost
            result
          end
        end
      end

      # Раскладывает URI для MQ в переменные окружения.
      #
      # @param env [Hash{String=>String}, ENV] Хэш переменных окружения или объект ENV (изменяется in-place)
      # @param uris [Array<URI>] Массив объектов URI
      # @return [void]
      # @api private
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

      # Конструирует имя переменной окружения с префиксом.
      #
      # @param prefix [String] Префикс (например, 'DATABASE')
      # @param name [String] Имя переменной (например, 'HOST')
      # @return [String] Объединенное имя (например, 'DATABASE_HOST')
      # @api private
      def self.prefixed_key(prefix, name)
        [prefix, name].select(&:present?).join('_')
      end

    end
  end
end