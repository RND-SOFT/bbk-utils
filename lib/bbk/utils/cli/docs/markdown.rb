module BBK
  module Utils
    module Cli
      class Docs::Markdown
        # генерация markdown
        # category_data = {
        #   category_data: {
        #   },
        #   env_vars: category.env_vars
        # }
        #
        # options = {
        #   columns: { env: "Название"},
        #   alignments: { 1 => :center, 3 => :center }, # :left, :right, :center для каждой колонки
        #   wrappers: { 1 => "`", 3 => "`" }, # wrappers - символ или строка для обрамления значений колонки, например: "`", "```", "**"
        #   title_level: 4, # уровень заголовка от 1 до 6
        #   warning: {
        #     column_index: 3, # индекс колонки для вывода предупреждений
        #     mode: :footnote # или :inline
        #   }
        # }

        attr_reader :opts

        def initialize(opts = {})
          @opts = opts
        end

        def generate(category)
          # Соберем заголовок
          level = opts[:title_level].clamp(1, 6)
          title = "#{'#' * level} (#{category.id}) #{category.name}"
          desc = category.desc.to_s

          # Конвертируем данные в формат для таблицы
          rows, footnotes = generate_rows(category, opts)
          # Создаем таблицу с заголовком и описанием

          table = generate_table(opts[:columns].values, opts[:alignments], rows)
          [
            title,
            '',
            desc,
            '',
            *table,
            '',
            *footnotes
          ].join("\n")
        end

        def generate_rows(category, opts)
          # извлекаем даныне
          rows = category.cfgs.map do |cfg|
            opts[:columns].keys.each_with_object([]) do |key, row|
              row << cfg[key.to_sym]
            end
          end

          # Применяем обрамление к значениям
          rows = wrap_row_values(rows, opts[:wrappers])

          # Применяем форматирование предупреждений
          rows, footnotes = process_warnings(rows, category, opts[:warning])

          [rows, footnotes]
        end

        def wrap_row_values(rows, wrappers)
          return rows if wrappers.empty?

          rows.map do |row|
            row.each_with_index.map do |value, index|
              wrapper = wrappers[index]
              if wrapper && !value.nil? # может быть пустым
                "#{wrapper}#{value}#{wrapper}"
              else
                value
              end
            end
          end
        end

        def process_warnings(rows, category, warning_opts)
          return [rows, []] if !warning_opts || !warning_opts[:column_index]

          column_index = warning_opts[:column_index]
          mode = warning_opts[:mode] || :footnote
          footnotes = []
          footnote_counter = 1

          processed_rows = rows.each_with_index.map do |row, row_index|
            cfg = category.cfgs[row_index]
            warning = cfg[:warning]

            if warning && !warning.empty?
              case mode
              when :footnote
                # Добавляем номер сноски
                id = "#{category.id}_#{footnote_counter}"
                row[column_index] = "#{row[column_index]} [^#{id}]"
                footnotes << "[^#{id}]: #{warning}"
                footnote_counter += 1
              when :inline
                # Добавляем предупреждение жирным текстом с переносом строки
                row[column_index] = "#{row[column_index]}<br>⚠️ **#{warning}**"
              end
            end
            row
          end

          [processed_rows, footnotes]
        end

        def generate_table(headers = [], alignments = {}, rows)
          # Вычисляем ширину колонок
          column_widths = if headers.any?
                            headers.map(&:size)
                          else
                            Array.new(rows[0].count, 0)
                          end

          rows.each do |row|
            row.each_with_index do |data, i|
              column_widths[i] = data.to_s.size if data.to_s.size > column_widths[i]
            end
          end

          # Создаем заголовок таблицы
          if headers.any?
            header_string = '|'
            separator_string = '|'

            headers.each_with_index do |header, col|
              header_string += " #{header.ljust(column_widths[col])} |"

              # Создаем разделитель с учетом выравнивания
              separator_string += case alignments[col]
                                  when :right
                                    "#{'-' * (column_widths[col] + 1)}:|"
                                  when :center
                                    if column_widths[col] >= 1
                                      ":#{'-' * column_widths[col]}:|"
                                    else
                                      '::|'
                                    end
                                  when :left
                                    ":#{'-' * (column_widths[col] + 1)}|"
                                  else
                                    "#{'-' * (column_widths[col] + 2)}|"
                                  end
            end

          end

          # Создаем строки данных
          lines = rows.map do |row|
            line = row.each_with_index.map do |value, col|
              value.to_s.ljust(column_widths[col])
            end.join(' | ')

            "| #{line} |"
          end

          [
            header_string,
            separator_string,
            *lines
          ]
        end
      end
    end
  end
end
