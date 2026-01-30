require 'yaml'
require 'optparse'


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

             opts.on("-h", "--help", "Prints this help") do
               puts opts
               exit
             end
          end.parse!(args)

          output_file = Rails.root.join(options[:output])
          config_file = Rails.root.join(options[:config])

          if File.exist?(config_file)
            config = YAML.load_file(config_file) || {}
          else
            puts "Config file not found: #{config_file}. Continuing without config."
            config = {}
          end

          cfg = BBK::Utils::Config.instance.as_json.deep_dup
          cfg = cfg[BBK::Utils::Config.instance.name] unless BBK::Utils::Config.instance.name.nil?

          BBK::Utils::Config.instance.send(:store_with_subconfigs).each do |k, v|
            if v[:default]&.class&.to_s == "Fugit::Duration"
              cfg[k][:default] = v[:default].original
            end

            if v[:default]
              cfg[k][:class] = "#{v[:default].class}"
            end
          end

          env_prefix_order = config.fetch('env_prefix_order', [])

          matching, remaining = separate(cfg, env_prefix_order)

          File.open(output_file, 'w') do |file|
            file.puts "# Переменные окружения\n\n"
            file.puts to_markdown(matching)
            file.puts "\n\n"
            file.puts to_markdown(remaining.sort)
          end

          puts "Documentation saved to: #{output_file}"
        end

        def separate(cfg, env_prefix_order)
          matching = {}
          remaining = {}

          cfg.each do |key, value|
            matched = env_prefix_order.any? do |prefix|
              key == prefix || key.start_with?(prefix + '_')
            end

            if matched
              matching[key] = value
            else
              remaining[key] = value
            end
          end

          [matching, remaining]
        end

        def to_markdown(cfg, columns = { :env => "Название", :desc => "Описание", :default => "По умолчанию", :class => "Тип"} )
          rows = cfg_to_array(cfg, columns.keys)

          create_markdown_table(rows, columns.values)
        end


        def cfg_to_array(cfg, keys)
          cfg.each_with_object([]) do |entry, rows|
            rows << keys.each_with_object([]) do |key, row|
              row << entry[1][key]
            end
          end
        end

        def create_markdown_table(rows, headers = [])
          return "| No data |" if rows.empty?

          column_widths = if headers.size != 0
            headers.map(&:size)
          else
            Array.new(rows[0].count, 0)
          end

          rows.each do |row|
            row.each_with_index do |string, i|
              column_widths[i] = string.to_s.size if string.present? && string.to_s.size > column_widths[i]
            end
          end

          markdown_table = []

          # Создаем заголовок таблицы, если он есть
          if headers.size != 0
            header_string = "|"
            separator_string = "|"

            headers.each_with_index do |header, col|
              header_string += " #{header.ljust(column_widths[col])} |"
              separator_string += "-#{'-' * column_widths[col]}-|"
            end

            markdown_table << header_string
            markdown_table << separator_string
          end

          # Создаем строки данных
          rows_string = []
          rows.each do |row|
            row_string = "|"
            row.each_with_index do |data, col|
              value = (data || '').to_s
              row_string += " #{value.ljust(column_widths[col])} |"
            end
            rows_string << row_string
          end
          markdown_table += rows_string

        end
      end
    end
  end
end

#   "BILLING_ENABLED"=>
#    {:env=>"BILLING_ENABLED",
#     :file=>nil,
#     :required=>false,
#     :default=>false,
#     :desc=>"Send data to billing by api",
#     :bool=>true,
#     :type=>
#      #<Method: BBK::Utils::Config::BooleanCaster.cast(value) /home/user/.asdf/installs/ruby/3.2.2/lib/ruby/gems/3.2.0/gems/bbk-utils-1.1.2.304819/lib/bbk/utils/config.rb:27      
