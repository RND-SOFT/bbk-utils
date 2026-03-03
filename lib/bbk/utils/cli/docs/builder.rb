module BBK
  module Utils
    module Cli
      # Класс-строитель документации по категориям конфигурации
      #
      # Группирует конфигурационные параметры по категориям,
      # обеспечивает сортировку и генерацию документации в различных форматах
      class Docs::Builder
        # Инициализирует строитель документации
        #
        # @param bbk [Hash] конфигурация BBK
        # @param config [Hash] конфигурация документирования
        # @option config [Hash] :categories настройки категорий
        def initialize(bbk, config)
          @bbk = bbk
          @config = config

          @categories = config[:categories].each_with_object({}) do |(name, c), cats|
            cats[name.to_s] = Category.new(id: name.to_s, **c)
          end

          @default = Category.new(id: 'other', name: 'Other')
          @categories[@default.id] = @default
        end

        # Выполняет разбор конфигурации по категориям
        #
        # @return [self] возвращает сам объект для цепочного вызова
        def run
          @bbk.each do |(env_name, cfg)|
            category = @categories[cfg[:category]]
            category ||= @categories.values.find { |c| c.match?(env_name) } || @default

            category.add(cfg)
          end

          @sorted = @categories.values.sort_by { |category| [category.order, category.id.to_s] }
          self
        end

        # Преобразует документацию в JSON-хеш
        #
        # @param _args [Array] игнорируемые аргументы
        # @param _kwargs [Hash] игнорируемые именованные аргументы
        # @return [Hash] хеш со структурой документации по категориям
        def as_json(*_args, **_kwargs)
          @sorted.each_with_object({}) do |category, result|
            result[category.id] = category.as_json
          end
        end

        # Преобразует документацию в JSON-строку
        #
        # @param args [Array] аргументы для JSON-генерации
        # @param kwargs [Hash] именованные аргументы для JSON-генерации
        # @return [String] JSON-строка документации
        def to_json(*args, **kwargs)
          as_json.to_json(*args, **kwargs)
        end

        # Генерирует документацию в формате Markdown
        #
        # @return [String] markdown-разметка полной документации
        def to_markdown
          markdown_opts = {
            columns: { env: 'Название', _class: 'Тип', desc: 'Описание', default: 'Умолчание' },
            alignments: { 1 => :center, 3 => :center }, # :left, :right, :center для каждой колонки
            wrappers: { 1 => '`', 3 => '`' }, # символ или строка для обрамления значений колонки, например: "`", "```", "**"
            title_level: 4, # уровень заголовка от 1 до 6
            warning: {
              column_index: 2,
              # mode: :footnote # :footnote или :inline
              mode: :inline # :footnote или :inline
            }
          }

          generator = Docs::Markdown.new(markdown_opts)

          @sorted.map do |category|
            category.cfgs.any? ? generator.generate(category) : ''
          end.join("\n")
        end
      end

      # Структура категории для группировки конфигураций
      #
      # @!attribute [r] id
      #   @return [String] идентификатор категории
      # @!attribute [r] name
      #   @return [String] название категории
      # @!attribute [r] desc
      #   @return [String] описание категории
      # @!attribute [r] envs
      #   @return [Array<String>] список переменных окружения категории
      # @!attribute [r] order
      #   @return [Numeric] порядок сортировки
      # @!attribute [r] patterns
      #   @return [Array<String>] шаблоны для поиска элементов категории
      # @!attribute [r] cfgs
      #   @return [Array<Hash>] конфигурации категории
      Category = Struct.new(:id, :name, :desc, :envs, :order, :patterns, :cfgs, keyword_init: true) do
        # Инициализирует категорию
        #
        # @param kwargs [Hash] параметры категории
        # @option kwargs [String] :id идентификатор категории
        # @option kwargs [String] :name название категории
        # @option kwargs [String] :desc описание категории
        # @option kwargs [Array<String>] :envs переменные окружения
        # @option kwargs [Numeric] :order порядок сортировки
        # @option kwargs [Array<String>] :patterns шаблоны поиска
        # @option kwargs [Array<Hash>] :cfgs конфигурации
        def initialize(**kwargs)
          kwargs[:id] = kwargs[:id].to_s
          kwargs[:name] = kwargs[:name].to_s || kwargs[:id].capitalize
          kwargs[:desc] = kwargs[:desc].to_s

          kwargs[:patterns] ||= []
          kwargs[:envs] ||= []
          kwargs[:order] ||= Float::INFINITY
          kwargs[:cfgs] ||= []

          super
        end

        # Проверяет соответствие имени переменной окружающей категории
        #
        # @param env_name [String, Symbol] имя переменной окружения
        # @return [Boolean] true если соответствует категории
        def match?(env_name)
          return true if envs.any? { |e| e == env_name.to_s.strip }

          return true if patterns.any? { |p| env_name.to_s.strip.start_with?(p) }

          false
        end

        # Добавляет конфигурацию в категорию
        #
        # @param cfg [Hash] конфигурация для добавления
        # @return [self] возвращает сам объект для цепочного вызова
        def add(cfg)
          cfgs << cfg
          self.cfgs = cfgs.sort_by { |c| c[:env] }
          self
        end
      end
    end
  end
end
