module Env
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
  def self.to_markdown(category_data, options = {})
    opts = options
    category_info = category_data[:category_data]

    # Соберем заголовок 
    level = opts[:title_level].clamp(1, 6)
    id_part = category_info[:id].to_s.camelize

    if category_info[:name] || category_info[:name_ru]
      title = "#{'#' * level}"
      title += " #{category_info[:name]}" if category_info[:name]
      title += category_info[:name] ? " (#{category_info[:name_ru]})" : " #{category_info[:name_ru]}" if category_info[:name_ru]
    else
      title = "#{'#' * level} #{id_part}"
    end

    description = if category_info[:desc].present? && category_info[:desc_ru].present?
      "#{category_info[:desc]} (#{category_info[:desc_ru]})"
    elsif category_info[:desc].present?
      category_info[:desc]
    elsif category_info[:desc_ru].present?
      category_info[:desc_ru]
    end

    # Получаем данные переменных
    env_vars = category_data[:env_vars] || {}

    # Конвертируем данные в формат для таблицы
    rows = env_vars_to_rows(env_vars, opts[:columns].keys)

    # Применяем обрамление к значениям
    rows = wrap_values(rows, opts[:wrappers])

    # Применяем форматирование предупреждений
    rows, footnotes = process_warnings(rows, env_vars, opts[:warning])

    # Создаем таблицу с заголовком и описанием
    markdown = create_category_markdown(rows, opts[:columns].values, opts[:alignments], 
                            title, description)

    # Добавляем сноски если они есть и используется режим footnote
    if footnotes && footnotes.any?
      markdown += "\n\n" + footnotes.map { |note| "> #{note}" }.join("\n")
    end

    markdown
  end

  class << self

    private
  
    def env_vars_to_rows(env_vars, keys)
      rows = []
  
      env_vars.each do |env_name, env_data|
        rows << keys.each_with_object([]) do |key, row|
          row << env_data[key]
        end
      end
  
      rows
    end
  
    def wrap_values(rows, wrappers)
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

    def process_warnings(rows, env_vars, warning_opts)
      return [rows, []] if !warning_opts || !warning_opts[:column_index]

      column_index = warning_opts[:column_index]
      mode = warning_opts[:mode] || :footnote
      footnotes = []
      footnote_counter = 1

      processed_rows = rows.each_with_index.map do |row, row_index|
        env_name = env_vars.keys[row_index]
        warning = env_vars[env_name][:warning]

        if warning && !warning.empty?
          case mode
          when :footnote
            # Добавляем номер сноски
            row[column_index] = "#{row[column_index]} <sup>#{footnote_counter}</sup>"
            footnotes << "#{footnote_counter} — #{warning}"
            footnote_counter += 1
          when :inline
            # Добавляем предупреждение жирным текстом с переносом строки
            row[column_index] = "#{row[column_index]}<br>**#{warning}**"
          end
        end
        row
      end

      [processed_rows, footnotes]
    end

    def create_category_markdown(rows, headers = [], alignments = {}, title = nil, description = nil)
      markdown_lines = []
  
      # Добавляем заголовок категории
      if title
        markdown_lines << title
        markdown_lines << ""
      end
  
      # Добавляем описание категории
      if description && !description.empty?
        markdown_lines << description
        markdown_lines << ""
      end
  
      # Если нет данных, выводим заглушку
      if rows.empty?
        markdown_lines << "| No data |"
        return markdown_lines.join("\n")
      end
  
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
        header_string = "|"
        separator_string = "|"
  
        headers.each_with_index do |header, col|
          header_string += " #{header.ljust(column_widths[col])} |"
  
          # Создаем разделитель с учетом выравнивания
          case alignments[col]
          when :right
            separator_string += "#{'-' * (column_widths[col] + 1)}:|"
          when :center
            if column_widths[col] >= 1
              separator_string += ":#{'-' * column_widths[col]}:|"
            else
              separator_string += "::|"
            end
          when :left
            separator_string += ":#{'-' * (column_widths[col] + 1)}|"
          else 
            separator_string += "#{'-' * (column_widths[col] + 2)}|"
          end
        end
  
        markdown_lines << header_string
        markdown_lines << separator_string
      end
  
      # Создаем строки данных
      rows.each do |row|
        row_string = "|"
        row.each_with_index do |data, col|
          value = data.to_s
  
          row_string += " #{value.ljust(column_widths[col])} |"
        end
        markdown_lines << row_string
      end
  
      markdown_lines.join("\n")
    end
  end
end