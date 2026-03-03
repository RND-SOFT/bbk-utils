module BBK
  module Utils
    module Cli
      # Класс для генерации документации в формате Markdown
      #
      # Создает таблицы с переменными окружения, параметрами конфигурации и т.д.
      # Поддерживает настраиваемые колонки, выравнивание, обрамление значений
      # и предупреждения в двух режимах: сноски или встроенные
      class Docs::Markdown
        # Генерация markdown-документации для категории
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

        # Инициализирует генератор Markdown
        #
        # @param opts [Hash] опции генерации
        # @option opts [Hash] :columns отображаемые колонки с заголовками
        # @option opts [Hash] :alignments выравнивание для каждой колонки
        # @option opts [Hash] :wrappers обрамление значений колонок
        # @option opts [Integer] :title_level уровень заголовка (1-6)
        # @option opts [Hash] :warning настройки вывода предупреждений
        def initialize(opts = {})
          @opts = opts
        end

        # Генерирует markdown-документацию для заданной категории
        #
        # @param category [Docs::Builder::Category] категория конфигурации
        # @return [String] markdown-разметка документации
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

        # Генерирует строки для таблицы документации
        #
        # @param category [Docs::Builder::Category] категория конфигурации
        # @param opts [Hash] опции генерации
        # @return [Array] массив строк и сносок
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

        # Применяет обрамление к значениям в строках таблицы
        #
        # @param rows [Array<Array>] строки таблицы
        # @param wrappers [Hash] хеш обрамления по индексам колонок
        # @return [Array<Array>] строки с обрамленными значениями
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

        # Обрабатывает предупреждения для строк таблицы
        #
        # @param rows [Array<Array>] строки таблицы
        # @param category [Docs::Builder::Category] категория конфигурации
        # @param warning_opts [Hash] опции обработки предупреждений
        # @option warning_opts [Integer] :column_index индекс колонки для предупреждений
        # @option warning_opts [Symbol] :mode режим вывода (:footnote или :inline)
        # @return [Array] кортеж из обработанных строк и массива сносок
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

        # Генерирует таблицу в формате Markdown
        #
        # @param headers [Array<String>] заголовки колонок
        # @param alignments [Hash] выравнивание для каждой колонки
        # @param rows [Array<Array>] строки данных таблицы
        # @return [Array<String>] массив строк markdown-таблицы
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
