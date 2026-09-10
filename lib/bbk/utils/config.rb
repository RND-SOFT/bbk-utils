# frozen_string_literal: true

module BBK
  module Utils
    # Класс управления конфигурацией приложения через переменные окружения.
    #
    # Предоставляет декларативный способ описания конфигурационных параметров
    # с поддержкой префиксов, подконфигураций, приведения типов, безопасных значений
    # и файловых конфигураций. Реализует паттерн Singleton.
    #
    # @example Базовое использование
    #   BBK::Utils::Config.instance.tap do |cfg|
    #     cfg.optional('LOG_LEVEL', default: 'info', desc: 'Уровень логирования')
    #     cfg.require('DATABASE_URL', desc: 'Строка подключения к БД')
    #     cfg.optional('REDIS_URL', default: 'redis://localhost:6379/0')
    #   end
    #   BBK::Utils::Config.run!(ENV)
    #
    #   # Доступ к значениям
    #   BBK::Utils::Config['LOG_LEVEL']    # => "info"
    #   BBK::Utils::Config['DATABASE_URL'] # => значение из ENV
    #
    # @example Использование с префиксами
    #   config = BBK::Utils::Config.instance(prefix: 'MYAPP')
    #   config.optional('PORT', default: 3000)
    #   config.run!(ENV)
    #   # Читает переменную MYAPP_PORT из ENV
    #
    # @example Подконфигурации
    #   config = BBK::Utils::Config.instance
    #   config.subconfig(prefix: 'DB') do |db|
    #     db.require('HOST', desc: 'Хост базы данных')
    #     db.optional('PORT', default: '5432')
    #   end
    #   config.run!(ENV)
    #   # Читает переменные DB_HOST и DB_PORT из ENV
    #
    # @note Все методы класса делегируются единственному экземпляру (Singleton)
    # @see Config::BooleanCaster Класс для приведения булевых значений
    class Config

      # @return [String] Разделитель между частями префикса
      PREFIX_SEP = '_'

      # @return [String] Заглушка для отображения безопасных значений в выводе
      FILTERED_VALUE = '[FILTERED]'

      # @return [Hash] Хранилище конфигурационных элементов
      attr_accessor :store

      # @return [String, nil] Имя конфигурации (для отображения)
      attr_accessor :name

      # @return [String, nil] Префикс данной конфигурации
      attr_reader :prefix

      # @return [String] Полный префикс с учётом родительских (для ENV)
      attr_reader :env_prefix

      # @return [Config, nil] Родительская конфигурация
      attr_reader :parent

      # Ошибка при обращении к несуществующему ключу конфигурации
      class KeyError < StandardError; end

      # Класс для приведения значений к булевому типу.
      #
      # Распознаёт широкий набор "ложных" значений: 0, 'f', 'false', 'off' и их варианты.
      # Всё остальное считается истиной. Пустые значения возвращают +nil+.
      #
      # @example
      #   BooleanCaster.cast('true')  # => true
      #   BooleanCaster.cast('0')     # => false
      #   BooleanCaster.cast('off')   # => false
      #   BooleanCaster.cast(nil)     # => nil
      #   BooleanCaster.cast('')      # => nil
      #   BooleanCaster.cast('yes')   # => true
      class BooleanCaster

        # Множество значений, интерпретируемых как +false+
        FALSE_VALUES = [
          false, 0,
          '0', :"0",
          'f', :f,
          'F', :F,
          'false', false,
          'FALSE', :FALSE,
          'off', :off,
          'OFF', :OFF
        ].to_set.freeze

        # Приводит значение к булевому типу.
        #
        # @param value [Object] Значение для приведения
        # @return [Boolean, nil] +true+, +false+ или +nil+ (для пустых значений)
        def self.cast(value)
          if value.nil? || value == ''
            nil
          else
            !FALSE_VALUES.include?(value)
          end
        end

      end

      # Возвращает единственный экземпляр конфигурации (Singleton).
      #
      # @param prefix [String, nil] Префикс для переменных окружения (только при первом вызове)
      # @return [Config] Единственный экземпляр
      #
      # @example
      #   config = BBK::Utils::Config.instance
      #   config = BBK::Utils::Config.instance(prefix: 'MYAPP')
      def self.instance(prefix: nil)
        @instance ||= new(prefix: prefix)
      end

      # Приводит значение к булевому типу.
      #
      # @param value [Object] Значение для приведения
      # @return [Boolean, nil] Результат приведения
      # @see BooleanCaster.cast
      def self.parse_bool_value(value)
        BooleanCaster.cast(value)
      end

      # Делегирование методов экземпляра на уровень класса
      # 
      # @!method self.map(env, file, required: true, desc: nil, bool: false, key: nil, rewrite: true, category: nil, warning: nil)
      #   @see #map
      # @!method self.require(env, desc: nil, bool: false, type: nil, key: nil, rewrite: true, secure: false, category: nil, warning: nil)
      #   @see #require
      # @!method self.optional(env, default: nil, desc: nil, bool: false, type: nil, key: nil, rewrite: true, secure: false, category: nil, warning: nil)
      #   @see #optional
      # @!method self.run!(source = ENV)
      #   @see #run!
      # @!method self.[](key)
      #   @see #[]
      # @!method self.[]=(key, value)
      #   @see #[]=
      # @!method self.content(key)
      #   @see #content
      # @!method self.to_s
      #   @see #to_s
      # @!method self.as_json(*args)
      #   @see #as_json
      # @!method self.to_json(*args)
      #   @see #to_json
      # @!method self.to_yaml(*args)
      #   @see #to_yaml
      # @!method self.fetch(key, default = nil)
      #   @see #fetch
      # @!method self.root?
      #   @see #root?
      class << self

        delegate :map, :require, :optional, :run!, :[], :[]=, :content, :to_s,
                 :to_json, :as_json, :to_yaml, :fetch, :root?,
                 to: :instance

      end

      # Инициализирует новый экземпляр конфигурации.
      #
      # Обычно не вызывается напрямую — используйте {.instance}.
      #
      # @param name [String, nil] Имя конфигурации (для отображения в логах)
      # @param prefix [String, nil] Префикс для переменных окружения
      # @param parent [Config, nil] Родительская конфигурация (для подконфигураций)
      #
      # @example
      #   config = BBK::Utils::Config.new(name: 'myapp', prefix: 'MYAPP')
      def initialize(name: nil, prefix: nil, parent: nil)
        @name = name
        @store = {}
        @parent = parent
        @subconfigs = []
        @prefix = normalize_key(prefix)
        @prefixes = if parent.nil?
          [@prefix]
        else
          parent.prefixes.dup + [@prefix]
        end.compact
        @env_prefix = normalize_key(@prefixes.join(PREFIX_SEP))
      end

      # Регистрирует файловый конфигурационный параметр.
      #
      # Значение переменной окружения записывается в указанный файл.
      # Используется для сертификатов, ключей и других файловых данных.
      #
      # @param env [String] Имя переменной окружения (без префикса)
      # @param file [String] Путь к файлу, куда будет записано значение
      # @param required [Boolean] Обязательность параметра (по умолчанию: true)
      # @param desc [String, nil] Описание параметра
      # @param bool [Boolean] (устарел) Не используется для файловых параметров, оставлен для совместимости
      # @param key [String, nil] Альтернативное имя переменной окружения
      # @param rewrite [Boolean] Перезаписывать при повторной регистрации (по умолчанию: true)
      # @param category [String, nil] Имя категории, к которой относится параметр.
      #   Используется генератором документации `BBK::Utils::Cli::Docs::Builder`
      # @param warning [String, nil] Предупреждение для отображения
      # @return [void]
      #
      # @example
      #   config.map('SSL_CERT', '/etc/ssl/cert.pem', desc: 'SSL-сертификат')
      #   config.run!(ENV)
      #   # Значение ENV['SSL_CERT'] будет записано в /etc/ssl/cert.pem
      def map(env, file, required: true, desc: nil, bool: false, key: nil, rewrite: true, category: nil, warning: nil)
        conf_key = full_prefixed_key(env)
        return if @store.key?(conf_key) && !rewrite

        @store[conf_key] = {
          env:      full_prefixed_key(key || env),
          file:     file,
          required: required,
          desc:     desc,
          bool:     bool,
          type:     nil,
          category: category,
          warning:  warning
        }
      end

      # Регистрирует обязательный конфигурационный параметр.
      #
      # При отсутствии переменной в источнике во время {#run!} будет выброшено исключение.
      #
      # @param env [String] Имя переменной окружения (без префикса)
      # @param desc [String, nil] Описание параметра
      # @param bool [Boolean] Интерпретировать как булево значение (по умолчанию: false)
      # @param type [#call, Class, nil] Кастер типа: объект с методом +call+ или класс с методом +new+
      #   *Примечание:* для встроенных классов (например, `Integer`, `Float`) передавайте `method(:Integer)`, так как они не имеют публичного метода `new`.
      # @param key [String, nil] Альтернативное имя переменной окружения (используется для чтения из ENV).
      #   Например: `config.require('MY_DB', key: 'DATABASE_URL')` прочитает `DATABASE_URL`,
      #   но в коде вы будете обращаться к нему как `config['MY_DB']`.
      # @param rewrite [Boolean] Перезаписывать при повторной регистрации (по умолчанию: true)
      # @param secure [Boolean] Скрывать значение в выводе (по умолчанию: false)
      # @param category [String, nil] Имя категории, к которой относится параметр.
      #   Используется генератором документации `BBK::Utils::Cli::Docs::Builder`
      # @param warning [String, nil] Предупреждение для отображения
      # @return [void]
      # @raise [ArgumentError] Если одновременно указаны +bool+ и +type+
      #
      # @example
      #   config.require('DATABASE_URL', desc: 'Строка подключения к БД')
      #   config.require('API_KEY', secure: true, desc: 'Секретный ключ')
      #   config.require('WORKERS_COUNT', type: method(:Integer), desc: 'Число воркеров')
      def require(env, desc: nil, bool: false, type: nil, key: nil, rewrite: true, secure: false, category: nil, warning: nil)
        raise ArgumentError.new('Specified type and bool') if bool && type.present?

        type = BBK::Utils::Config::BooleanCaster.singleton_method(:cast) if bool
        conf_key = full_prefixed_key(env)
        return if @store.key?(conf_key) && !rewrite

        @store[conf_key] = {
          env:      full_prefixed_key(key || env),
          file:     nil,
          required: true,
          desc:     desc,
          bool:     bool,
          type:     type,
          secure:   secure,
          category: category,
          warning:  warning
        }
      end

      # Регистрирует опциональный конфигурационный параметр со значением по умолчанию.
      #
      # @param env [String] Имя переменной окружения (без префикса)
      # @param default [Object] Значение по умолчанию (по умолчанию: nil)
      # @param desc [String, nil] Описание параметра
      # @param bool [Boolean] Интерпретировать как булево значение (по умолчанию: false)
      # @param type [#call, Class, nil] Кастер типа: объект с методом +call+ или класс с методом +new+
      #   *Примечание:* для встроенных классов (например, `Integer`, `Float`) передавайте `method(:Integer)`, так как они не имеют публичного метода `new`.
      # @param key [String, nil] Альтернативное имя переменной окружения (используется для чтения из ENV).
      #   Например: `config.optional('REDIS_URL', key: 'REDIS_CACHE_URL', default: 'redis://localhost:6379/0')` прочитает `REDIS_CACHE_URL`,
      #   но в коде вы будете обращаться к нему как `config['REDIS_URL']`.
      # @param rewrite [Boolean] Перезаписывать при повторной регистрации (по умолчанию: true)
      # @param secure [Boolean] Скрывать значение в выводе (по умолчанию: false)
      # @param category [String, nil] Имя категории, к которой относится параметр.
      #   Используется генератором документации `BBK::Utils::Cli::Docs::Builder`
      # @param warning [String, nil] Предупреждение для отображения
      # @return [void]
      # @raise [ArgumentError] Если одновременно указаны +bool+ и +type+
      #
      # @example
      #   config.optional('LOG_LEVEL', default: 'info', desc: 'Уровень логирования')
      #   config.optional('PORT', default: '3000', type: method(:Integer))
      #   config.optional('DEBUG', default: false, bool: true)
      #   config.optional('PASSWORD', default: '', secure: true)
      def optional(env, default: nil, desc: nil, bool: false, type: nil, key: nil, rewrite: true, secure: false, category: nil, warning: nil)
        raise ArgumentError.new('Specified type and bool') if bool && type.present?

        type = BBK::Utils::Config::BooleanCaster.singleton_method(:cast) if bool
        conf_key = full_prefixed_key(env)
        return if @store.key?(conf_key) && !rewrite

        @store[conf_key] = {
          env:      full_prefixed_key(key || env),
          file:     nil,
          required: false,
          default:  default,
          desc:     desc,
          bool:     true,
          type:     type,
          secure:   secure,
          category: category,
          warning:  warning
        }
      end

      # Запускает обработку всех зарегистрированных параметров.
      #
      # Проходит по всем элементам хранилища и читает значения из источника.
      # Рекурсивно обрабатывает все подконфигурации.
      #
      # @param source [Hash{String=>String}, #fetch] Источник значений (объект с методом #fetch, например ENV)
      # @return [nil]
      # @raise [RuntimeError] Если обязательный параметр отсутствует в источнике
      #
      # @example Чтение из ENV
      #   config.run!
      #
      # @example Чтение из хэша
      #   config.run!({ 'DATABASE_URL' => 'postgres://...' })
      def run!(source = ENV)
        @store.each_value do |item|
          process(source, item)
        end
        @subconfigs.each {|sub| sub.run!(source) }
        nil
      end

      # Создаёт подконфигурацию с собственным префиксом.
      #
      # Переменные окружения подконфигурации получают дополнительный префикс.
      # Например, при префиксе родителя 'APP' и префиксе подконфигурации 'DB',
      # переменная 'HOST' будет читаться как 'APP_DB_HOST'.
      #
      # @param prefix [String, Symbol] Префикс подконфигурации
      # @param name [String, nil] Имя подконфигурации
      # @yield [sub] Блок для регистрации параметров подконфигурации
      # @yieldparam sub [Config] Экземпляр подконфигурации
      # @return [Config] Созданная подконфигурация
      # @raise [ArgumentError] Если подконфигурация с таким префиксом уже существует
      #
      # @example
      #   config = BBK::Utils::Config.instance(prefix: 'APP')
      #   config.subconfig(prefix: 'DB', name: 'database') do |db|
      #     db.require('HOST')
      #     db.optional('PORT', default: '5432')
      #   end
      #   # Будут читаться переменные APP_DB_HOST и APP_DB_PORT
      def subconfig(prefix:, name: nil)
        raise ArgumentError.new("Subconfig with prefix #{prefix} already exists") if @subconfigs.any? {|sub| sub.prefix == prefix.to_s }

        sub = self.class.new(name: name, prefix: prefix, parent: self)
        @subconfigs << sub
        yield sub if block_given?
        sub
      end

      # Возвращает значение конфигурационного параметра.
      #
      # Поиск происходит с учётом префиксов, вверх по иерархии (к родителю)
      # и вниз (в подконфигурации).
      #
      # @param key [String] Имя параметра
      # @return [Object] Значение параметра
      # @raise [Config::KeyError] Если параметр не найден
      #
      # @example
      #   BBK::Utils::Config['LOG_LEVEL'] # => "info"
      def [](key)
        self.get(key, search_up: true, search_down: true)[:value]
      end

      # Устанавливает значение конфигурационного параметра.
      #
      # @param key [String] Имя параметра
      # @param value [Object] Новое значение
      # @return [Object] Установленное значение
      #
      # @example
      #   BBK::Utils::Config['LOG_LEVEL'] = 'debug'
      def []=(key, value)
        @store[normalize_key(key)][:value] = value
      end

      # Возвращает содержимое параметра.
      #
      # Для файловых параметров читает содержимое файла.
      # Для остальных возвращает значение.
      #
      # @param key [String] Имя параметра
      # @return [String, Object] Содержимое файла или значение параметра
      #
      # @example
      #   config.content('SSL_CERT') # => содержимое файла сертификата
      def content(key)
        item = @store[normalize_key(key)]
        if (file = item[:file])
          File.read(file)
        else
          item[:value]
        end
      end

      # Возвращает значение параметра или значение по умолчанию.
      #
      # В отличие от {#[]}, не выбрасывает исключение при отсутствии параметра.
      #
      # @param key [String] Имя параметра
      # @param default [Object] Значение по умолчанию (по умолчанию: nil)
      # @return [Object] Значение параметра или +default+
      #
      # @example
      #   BBK::Utils::Config.fetch('LOG_LEVEL', 'warn') # => "info" (если значение установлено) или "warn" (если не установлено)
      #   BBK::Utils::Config.fetch('NONEXISTENT', 'fallback') # => "fallback"
      def fetch(key, default = nil)
        if (rec = self.get(key, search_up: true, search_down: true)) && rec.key?(:value)
          rec[:value]
        else
          default
        end
      rescue KeyError
        default
      end

      # Возвращает человекочитаемое представление конфигурации.
      #
      # Выводит все параметры с их значениями, описаниями и статусом обязательности.
      # Безопасные параметры отображаются как +[FILTERED]+.
      #
      # @return [String] Форматированный вывод конфигурации
      #
      # @example Вывод
      #   # Environment variables:
      #   #    <DATABASE_URL>                                     Строка подключения к БД
      #   #       -> "postgres://localhost/mydb"
      #   #    [LOG_LEVEL] (=info)                                Уровень логирования
      #   #       -> "info"
      def to_s
        result = StringIO.new
        result.puts "Environment variables#{@name ? " for #{@name}" : ''}:"
        padding = ' ' * 3
        sorted = store_with_subconfigs.values.sort_by do |item|
          [item[:file].present? ? 0 : 1, item[:required] ? 0 : 1]
        end

        sorted.each do |item|
          if item[:file]
            result.puts print_file_item(item, padding)
          else
            result.puts print_item(item, padding)
          end
        end
        result.string
      end

      # Возвращает конфигурацию как хэш.
      #
      # @param _args [Array] Игнорируется (для совместимости с ActiveSupport)
      # @return [Hash] Хэш вида { "ИМЯ_ПЕРЕМЕННОЙ" => { параметры } }
      # @note Если в конфигурации используются кастомные type-кастеры (Method, Proc, Class),
      #   поле `type` будет сериализовано как строковое представление объекта (например, "#<Method: Object(Kernel)#Integer(*)>").
      def as_json(*_args)
        values = store_with_subconfigs.values.sort_by do |item|
          [item[:file].present? ? 0 : 1, item[:required] ? 0 : 1]
        end.reduce({}) do |ret, item|
          ret.merge(item[:env] => item)
        end

        @name ? { @name => values } : values
      end

      # Возвращает конфигурацию в формате JSON.
      #
      # @param _args [Array] Игнорируется (для совместимости с ActiveSupport)
      # @return [String] JSON-представление конфигурации
      # @note Если в конфигурации используются кастомные type-кастеры (Method, Proc, Class),
      #   поле `type` будет сериализовано как строковое представление объекта (например, "#<Method: Object(Kernel)#Integer(*)>").
      def to_json(*_args)
        JSON.pretty_generate(as_json)
      end

      # Возвращает конфигурацию в формате YAML.
      #
      # @param _args [Array] Игнорируется (для совместимости с ActiveSupport)
      # @return [String] YAML-представление конфигурации
      # @note Если в конфигурации используются кастомные type-кастеры (Method, Proc, Class),
      #   поле `type` будет сериализовано как строковое представление объекта (например, "#<Method: Object(Kernel)#Integer(*)>").
      def to_yaml(*_args)
        JSON.parse(to_json).to_yaml
      end

      # Проверяет, является ли конфигурация корневой (не имеет родителя).
      #
      # @return [Boolean] +true+ если конфигурация корневая
      def root?
        @parent.nil?
      end

      protected

        # @return [Array<String>] Массив префиксов от корня до текущего уровня
        attr_reader :prefixes

        # Ищет конфигурационный элемент по ключу.
        #
        # @param key [String] Имя параметра
        # @param search_up [Boolean] Искать в родительских конфигурациях
        # @param search_down [Boolean] Искать в подконфигурациях
        # @return [Hash] Конфигурационный элемент
        # @raise [KeyError] Если параметр не найден
        # @api private
        def get(key, search_up: false, search_down: false)
          normalized_key = normalize_key(key)
          return @store[normalized_key] if @store.key?(normalized_key)

          prefix_key = full_prefixed_key(key)
          return @store[prefix_key] if @store.key?(prefix_key)

          if search_down
            sub_prefixed_keys(key).each do |pref_key|
              return @store[pref_key] if @store.key?(pref_key)

              subconf = @subconfigs.find {|sub| pref_key.starts_with?(sub.env_prefix) }
              next if subconf.nil?

              return subconf.get(pref_key, search_up: false, search_down: true)
            end
          end
          return @parent.get(key, search_up: true, search_down: false) if search_up && @parent

          raise KeyError.new("There is no such key: #{key} in config!")
        end

        # Возвращает все элементы хранилища включая подконфигурации.
        #
        # @return [Hash] Объединённое хранилище всех уровней
        # @api private
        def store_with_subconfigs
          res = @store.dup
          @subconfigs.each do |sub|
            res = res.merge(sub.store_with_subconfigs)
          end
          res
        end

      private

        # Нормализует ключ: переводит в верхний регистр, заменяет дефисы на подчёркивания.
        #
        # @param key [String, nil] Ключ для нормализации
        # @return [String, nil] Нормализованный ключ
        # @api private
        def normalize_key(key)
          return nil if key.nil?

          key.to_s.upcase.gsub('-', '_')
        end

        # Формирует полный ключ с учётом префикса.
        #
        # @param key [String] Базовый ключ
        # @return [String] Ключ с префиксом (например, "APP_DB_HOST")
        # @api private
        def full_prefixed_key(key)
          p_key = if env_prefix.empty?
            [key.to_s]
          else
            [env_prefix, key.to_s]
          end.join(PREFIX_SEP)
          normalize_key(p_key)
        end

        # Генерирует варианты ключей с разными комбинациями префиксов.
        #
        # @param key [String] Базовый ключ
        # @return [Enumerator] Перечислитель вариантов ключей
        # @api private
        def sub_prefixed_keys(key)
          Enumerator.new do |yielder|
            @prefixes.size.downto(0).each do |last_index|
              yielder << [*@prefixes[0...last_index], normalize_key(key)].compact.join(PREFIX_SEP)
            end
          end
        end

        # Обрабатывает один конфигурационный элемент: читает значение из источника.
        #
        # Логика обработки:
        # - Если значение присутствует или указан тип — обрабатывает значение
        # - Для файловых параметров — записывает значение в файл
        # - Для типизированных — применяет кастер типа
        # - Если значение отсутствует и параметр обязательный — выбрасывает ошибку
        # - Если значение отсутствует и параметр опциональный — использует дефолт
        #
        # @param source [Hash{String=>String}, #fetch] Источник значений (объект с методом #fetch, например ENV)
        # @param item [Hash] Конфигурационный элемент из хранилища
        # @return [void]
        # @raise [RuntimeError] Если обязательный параметр отсутствует
        # @api private
        def process(source, item)
          content = source.fetch(item[:env], item[:default])

          # Если данные есть, либо указан тип (нужно для того чтобы переменная была нужного типа)
          if content.present? || item[:type].present?
            if (file = item[:file])
              dirname = File.dirname(file)
              FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
              File.write(file, content)
              item[:value] = file
            else
              item[:value] = if (type = item[:type])
                if type.respond_to? :call
                  type.call(content)
                else
                  type.new(content)
                end
              else
                content
              end
            end
          elsif item[:required]
            required!(item)
          else
            item[:value] = if (file = item[:file]).present? && File.exist?(file)
              file
            else
              content
            end
          end
        rescue StandardError => e
          msg = "Failed processing #{item[:env]} parameter. #{e.inspect}"
          if $logger
            $logger.error msg
          else
            puts msg
          end
          raise
        end

        # Выбрасывает ошибку об отсутствии обязательного параметра.
        #
        # @param item [Hash] Конфигурационный элемент
        # @raise [RuntimeError] Всегда выбрасывает ошибку
        # @api private
        def required!(item)
          raise "ENV [#{item[:env]}] is required!"
        end

        # Формирует строку вывода для файлового параметра.
        #
        # @param item [Hash] Конфигурационный элемент
        # @param padding [String] Отступ для форматирования
        # @return [String] Форматированная строка
        # @api private
        def print_file_item(item, padding)
          line = "#{padding}File #{wrap_required(item)}"
          line = if item[:desc].present?
            "#{line.ljust(50)} #{item[:desc]}"
          else
            line
          end

          "#{line}\n#{padding * 2}-> #{item[:file].inspect}"
        end

        # Формирует строку вывода для обычного параметра.
        #
        # @param item [Hash] Конфигурационный элемент
        # @param padding [String] Отступ для форматирования
        # @return [String] Форматированная строка
        # @api private
        def print_item(item, padding)
          line = padding + wrap_required(item)
          if item[:default].present?
            def_value = if item[:secure]
              FILTERED_VALUE
            else
              item[:default]
            end
            line += " (=#{def_value})"
          end

          line = if item[:desc].present?
            "#{line.ljust(50)} #{item[:desc]}"
          else
            line
          end
          value = if item[:secure]
            FILTERED_VALUE
          else
            item[:value].inspect
          end
          "#{line}\n#{padding * 2}-> #{value}"
        end

        # Оборачивает имя переменной в скобки в зависимости от обязательности.
        #
        # Обязательные параметры выводятся в угловых скобках: <ИМЯ>
        # Опциональные параметры выводятся в квадратных скобках: [ИМЯ]
        #
        # @param item [Hash] Конфигурационный элемент
        # @return [String] Имя переменной в скобках
        # @api private
        def wrap_required(item)
          if item[:required]
            "<#{item[:env]}>"
          else
            "[#{item[:env]}]"
          end
        end

    end
  end
end