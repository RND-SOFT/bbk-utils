require 'fileutils'
require 'yaml'
require 'optparse'

module BBK
  module Utils
    module Cli
      # Класс для генерации документации по конфигурации BBK
      #
      # Обеспечивает парсинг аргументов командной строки, загрузку конфигурации
      # и генерацию документации в форматах JSON и Markdown
      class Docs
        # Инициализирует объект генератора документации
        #
        # @param argv [Array<String>] аргументы командной строки
        def initialize(argv)
          @argv = argv
        end

        # Основной метод запуска генерации документации
        #
        # @param argv [Array<String>] аргументы командной строки
        # @return [void]
        def run(argv = @argv)
          options = parse!(argv)

          bbk = extract_bbk_config

          config = load_configuration("#{__dir__}/bbkdocs.yml", options[:config])

          @builder = Builder.new(bbk, config).tap do |b|
            b.run
          end

          FileUtils.mkdir_p File.dirname(options[:categories])

          File.open(options[:categories], 'w') do |file|
            file << JSON.pretty_generate(@builder.as_json)
            puts "Documentation JSON saved to: #{options[:categories]}"
          end

          FileUtils.mkdir_p File.dirname(options[:output])

          File.open(options[:output], 'w') do |file|
            file << @builder.to_markdown
            puts "Documentation MArkdown saved to: #{options[:output]}"
          end
        end

        # Парсит аргументы командной строки
        #
        # @param argv [Array<String>] аргументы командной строки
        # @return [Hash] хеш с опциями конфигурации
        def parse!(argv)
          options = {
            config: './.bbkdocs.yml',
            output: './bbkdocs.md',
            categories: './bbkdocs.json'
          }

          OptionParser.new do |opts|
            opts.banner = 'Usage: bundle exec bin/bbkdocs [options]'

            opts.on('-c', '--config CONFIG', "Path to config file (default: #{options[:config]})") do |path|
              options[:config] = File.absolute_path(path.to_s.strip)
            end

            opts.on('-o', '--output OUTPUT', "Path to output file (default: #{options[:output]})") do |path|
              options[:output] = File.absolute_path(path.to_s.strip)
            end

            opts.on('-g', '--categories CATEGORIES',
                    "Path to categories output file (default: #{options[:categories]})") do |path|
              options[:categories] = File.absolute_path(path.to_s.strip)
            end

            opts.on('-h', '--help', 'Prints this help') do
              puts opts
              exit
            end
          end.parse!(argv)

          options
        end

        # Загружает и объединяет конфигурации из нескольких файлов
        #
        # @param files [Array<String>] пути к файлам конфигурации YAML
        # @return [Hash] объединенная конфигурация с символизированными ключами
        def load_configuration(*files)
          files.each_with_object({}) do |file, config|
            loaded = YAML.load_file(file).deep_symbolize_keys!

            config.deep_merge!(loaded) do |key, oldv, newv|
              result = newv

              if oldv.is_a?(Hash) || newv.is_a?(Hash)
                result = (oldv || {}).deep_merge(newv || {})
              elsif oldv.is_a?(Array) || newv.is_a?(Array)
                result = if key.to_s == 'patterns' || key.to_s == 'envs'
                           ([oldv].flatten + [newv].flatten).compact.map(&:to_s).map(&:strip)
                         else
                           (newv || [])
                         end
              else
                newv
              end

              result
            end
          end
        end

        # Извлекает конфигурацию BBK и преобразует её в удобный формат
        #
        # @return [Hash] конфигурация BBK с дополнительной информацией о типах
        def extract_bbk_config
          bbk_cfg = BBK::Utils::Config.instance.as_json.deep_dup
          bbk_cfg = bbk_cfg[BBK::Utils::Config.instance.name] unless BBK::Utils::Config.instance.name.nil?

          BBK::Utils::Config.instance.send(:store_with_subconfigs).each do |k, v|
            # "REQUEST_OPERATIONAL_INTERVAL"=>{:env=>"REQUEST_OPERATIONAL_INTERVAL", :file=>nil, :required=>false, :default=>#<Fugit::Duration:0x000078abf4b20f70 @original="1M", @options={}, @h={:mon=>1}>, :desc=>"Оперативный интервал Запросов: (NOW - INTERVAL, NOW]. Статистика по Запросам будет создаваться вплоть до <СЕЙЧАС - INTERVAL>. Округление до начала дня.", :bool=>true, :type=>#<Method: Object#duration_parser(raw_value) /home/user/dev/rndsoft/aggredator/consumers/apigw_AGG-4827/config/initializers/01_config.rb:8>, :secure=>false, :category=>nil, :warning=>nil, :value=>1 month}
            bbk_cfg[k][:default] = v[:default].original if v[:default]&.class&.to_s == 'Fugit::Duration'

            # "MQ_PORT"=>{:env=>"MQ_PORT", :file=>nil, :required=>false, :default=>"5671", :desc=>"Message Broker port", :bool=>true, :type=>nil, :secure=>false, :category=>nil, :warning=>nil, :value=>"5671"}
            # "INCOMING_ARCHIVE_ENABLED"=>{:env=>"INCOMING_ARCHIVE_ENABLED", :file=>nil, :required=>false, :default=>false, :desc=>"Включение подсистемы архивации входящих", :bool=>true, :type=>#<Method: BBK::Utils::Config::BooleanCaster.cast(value) /home/user/dev/rndsoft/aggredator/consumers/bbk-utils/lib/bbk/utils/config.rb:28>, :secure=>false, :category=>nil, :warning=>nil, :value=>false}
            unless v[:default].nil?
              bbk_cfg[k][:_class] = case v[:default]
                                    when Fugit::Duration then 'Duration'
                                    when TrueClass, FalseClass then 'bool'
                                    else
                                      v[:default].class.to_s
                                    end
            end
          end

          bbk_cfg.deep_symbolize_keys
        end
      end
    end
  end
end

require_relative 'docs/builder'
require_relative 'docs/markdown'

# пример одного элемента bbk_cfg после преобразований и до засовывания в Env::CategoryBuilder
#  "BILLING_ENABLED": {
#    "env": "BILLING_ENABLED",
#    "file": null,
#    "required": false,
#    "default": false,
#    "desc": "Send data to billing by api",
#    "bool": true,
#    "type": "#<Method: BBK::Utils::Config::BooleanCaster.cast(value) /home/user/dev/rndsoft/aggredator/consumers/bbk/utils/lib/bbk/utils/config.rb:28>",
#    "secure": false,
#    "category": null,
#    "warning": null,
#    "value": false,
#    "_class": "FalseClass"
#  },
