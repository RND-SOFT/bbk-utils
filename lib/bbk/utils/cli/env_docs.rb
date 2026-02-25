require 'yaml'
require 'optparse'

require_relative 'env/category_builder'
require_relative 'env/markdown_table'
                      
module BBK
  module Utils
    module Cli
      class EnvDocs
        def self.run(*args) new.run(*args) end

        def run(*args)
          options = {
            config: './.env_docs.yml',
            output: './env_docs.md'
          }

          OptionParser.new do |opts|
             opts.banner = "Usage: env_docs [options]"

             opts.on("-c", "--config CONFIG", "Path to config file (default: #{options[:config]})") do |c|
               options[:config] = c
             end

             opts.on("-o", "--output OUTPUT", "Path to output file (default: #{options[:output]})") do |o|
               options[:output] = o
             end

             opts.on("-g", "--categories CATEGORIES", "Path to categories output file (sample: ./env_categories.json)") do |g|
               options[:categories] = g
             end

             opts.on("-h", "--help", "Prints this help") do
               puts opts
               exit
             end
          end.parse!(args)

          bbk_cfg = BBK::Utils::Config.instance.as_json.deep_dup
          bbk_cfg = bbk_cfg[BBK::Utils::Config.instance.name] unless BBK::Utils::Config.instance.name.nil?

          BBK::Utils::Config.instance.send(:store_with_subconfigs).each do |k, v|
            if v[:default]&.class&.to_s == "Fugit::Duration"
              bbk_cfg[k][:default] = v[:default].original
            end

            unless v[:default].nil?
              bbk_cfg[k][:_class] = "#{v[:default].class}"
            end
          end

          builder = Env::CategoryBuilder.new(
            bbk_cfg,
            Rails.root.join(options[:config]), # TODO этот генератор только для Rails?
            "#{__dir__}/env_docs.yml"
          )
          # Получаем категории с переменными
          categories = builder.run

          if options[:categories]
            File.open(Rails.root.join(options[:categories]), 'w') do |file|
              file << builder.categories_inspect(categories)
            end
          end

          markdown_opts = {
            columns: { env: "Название", _class: "Тип", desc: "Описание", default: "Умолчание" },
            alignments: { 1 => :center, 3 => :center }, # :left, :right, :center для каждой колонки
            wrappers: { 1 => "`", 3 => "`" }, # символ или строка для обрамления значений колонки, например: "`", "```", "**"
            title_level: 4, # уровень заголовка от 1 до 6
            warning: {
              column_index: 2,
              mode: :inline  # :footnote или :inline
            }
          }

          File.open(Rails.root.join(options[:output]), 'w') do |file|
            file << generate_documentation(categories, markdown_opts)
          end

          puts "Documentation saved to: #{options[:output]}"
        end

        # генерация документации из всех категорий
        def generate_documentation(categories, markdown_opts = {})
          markdown_parts = []

          categories.each do |category_id, category|
            # Пропускаем категории без переменных
            next if category.env_vars.empty?

            # Подготавливаем данные для to_markdown
            category_data = {
              category_data: {
                id: category.id,
                name: category.name,
                name_ru: category.name_ru,
                desc: category.desc,
                desc_ru: category.desc_ru
              },
              env_vars: category.sorted_env_vars
            }

            # Генерируем markdown для категории
            markdown_parts << Env.to_markdown(category_data, markdown_opts)
            markdown_parts << "\n\n\n"
          end

          markdown_parts.join
        end

      end
    end
  end
end

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
