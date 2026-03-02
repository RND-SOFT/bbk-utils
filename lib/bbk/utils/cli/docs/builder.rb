module BBK
  module Utils
    module Cli
      class Docs::Builder
        def initialize(bbk, config)
          @bbk = bbk
          @config = config

          @categories = config[:categories].each_with_object({}) do |(name, c), cats|
            cats[name.to_s] = Category.new(id: name.to_s, **c)
          end

          @default = Category.new(id: 'other', name: 'Other')
          @categories[@default.id] = @default
        end

        def run
          @bbk.each do |(env_name, cfg)|
            category = @categories[cfg[:category]]
            category ||= @categories.values.find { |c| c.match?(env_name) } || @default

            category.add(cfg)
          end

          @sorted = @categories.values.sort_by { |category| [category.order, category.id.to_s] }
          self
        end

        def as_json(*_args, **_kwargs)
          @sorted.each_with_object({}) do |category, result|
            result[category.id] = category.as_json
          end
        end

        def to_json(*args, **kwargs)
          as_json.to_json(*args, **kwargs)
        end

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

      Category = Struct.new(:id, :name, :desc, :envs, :order, :patterns, :cfgs, keyword_init: true) do
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

        def match?(env_name)
          return true if envs.any? { |e| e == env_name.to_s.strip }

          return true if patterns.any? { |p| env_name.to_s.strip.start_with?(p) }

          false
        end

        def add(cfg)
          cfgs << cfg
          self.cfgs = cfgs.sort_by { |c| c[:env] }
          self
        end
      end
    end
  end
end
