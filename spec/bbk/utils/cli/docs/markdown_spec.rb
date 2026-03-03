require 'spec_helper'

RSpec.describe BBK::Utils::Cli::Docs::Markdown do
  let(:default_opts) do
    {
      columns: {
        env: 'Название',
        _class: 'Тип',
        desc: 'Описание',
        default: 'Умолчание'
      },
      alignments: {
        1 => :center,
        3 => :center
      },
      wrappers: {
        1 => '`',
        3 => '`'
      },
      title_level: 4,
      warning: {
        column_index: 2,
        mode: :inline
      }
    }
  end

  let(:instance) { described_class.new(default_opts) }

  let(:category) do
    double('Category',
           id: 'test',
           name: 'Test Category',
           desc: 'Test Description',
           cfgs: [
             { env: 'TEST_VAR1', _class: 'String', desc: 'Test var 1', default: 'value1', warning: nil },
             { env: 'TEST_VAR2', _class: 'Integer', desc: 'Test var 2', default: '42', warning: 'Be careful' },
             { env: 'TEST_VAR3', _class: 'Boolean', desc: 'Test var 3', default: 'true', warning: nil }
           ])
  end

  let(:category_without_warnings) do
    double('Category',
           id: 'test',
           name: 'Test Category',
           desc: 'Test Description',
           cfgs: [
             { env: 'TEST_VAR1', _class: 'String', desc: 'Test var 1', default: 'value1', warning: nil },
             { env: 'TEST_VAR2', _class: 'Integer', desc: 'Test var 2', default: '42', warning: nil }
           ])
  end

  describe '#initialize' do
    it 'stores options' do
      expect(instance.instance_variable_get(:@opts)).to eq(default_opts)
    end

    it 'defaults to empty opts if not provided' do
      instance = described_class.new
      expect(instance.instance_variable_get(:@opts)).to eq({})
    end

    it 'makes opts accessible via reader' do
      expect(instance.opts).to eq(default_opts)
    end
  end

  describe '#generate' do
    let(:opts) do
      {
        columns: { env: 'Env', desc: 'Description' },
        alignments: {},
        wrappers: {},
        title_level: 2,
        warning: {}
      }
    end
    let(:category) do
      double('Category',
             id: 'test',
             name: 'Test Category',
             desc: 'Test Description',
             cfgs: [
               { env: 'VAR1', desc: 'Desc 1', warning: nil },
               { env: 'VAR2', desc: 'Desc 2', warning: nil }
             ])
    end

    it 'generates markdown with header' do
      md = described_class.new(opts).generate(category)
      expect(md).to include('## (test) Test Category')
    end

    it 'includes category description' do
      md = described_class.new(opts).generate(category)
      expect(md).to include('Test Description')
    end

    it 'generates table with headers' do
      md = described_class.new(opts).generate(category)
      expect(md).to include('Env')
      expect(md).to include('Description')
    end

    it 'includes table separator' do
      md = described_class.new(opts).generate(category)
      expect(md).to match(/^\|[-|]+\|$/)
    end

    it 'includes config values' do
      md = described_class.new(opts).generate(category)
      expect(md).to include('VAR1')
      expect(md).to include('VAR2')
      expect(md).to include('Desc 1')
      expect(md).to include('Desc 2')
    end

    it 'clamps title level between 1 and 6' do
      opts[:title_level] = 0
      md = described_class.new(opts).generate(category)
      expect(md).to match(/^# /)

      opts[:title_level] = 10
      md = described_class.new(opts).generate(category)
      expect(md).to match(/^###### /)
    end

    it 'formats with title level 1' do
      opts[:title_level] = 1
      md = described_class.new(opts).generate(category)
      expect(md).to match(/^# /)
    end

    it 'formats with title level 6' do
      opts[:title_level] = 6
      md = described_class.new(opts).generate(category)
      expect(md).to match(/^###### /)
    end

    it 'returns complete markdown structure' do
      md = described_class.new(opts).generate(category)
      lines = md.split("\n")
      expect(lines[0]).to match(/^## /)
      expect(lines[1]).to be_empty
      expect(lines[2]).to eq('Test Description')
      expect(lines[3]).to be_empty
      expect(lines.size).to be > 4
    end
  end

  describe '#generate_rows' do
    let(:opts) do
      {
        columns: { env: 'Env', _class: 'Type', desc: 'Desc' },
        warnings: {}
      }
    end

    it 'generates rows for each config' do
      rows, footnotes = instance.generate_rows(category, default_opts)
      expect(rows.size).to eq(3)
    end

    it 'extracts values in column order' do
      rows, _ = instance.generate_rows(category, default_opts)
      expect(rows[0]).to match(['TEST_VAR1', '`String`', 'Test var 1', '`value1`'])
    end

    it 'returns empty footnotes by default' do
      _, footnotes = instance.generate_rows(category_without_warnings, default_opts)
      expect(footnotes).to eq([])
    end

    it 'handles nil values in rows' do
      cat_with_nil = double('Category',
                            id: 'test',
                            cfgs: [
                              { env: 'TEST', _class: nil, desc: 'Desc', default: nil, warning: nil }
                            ])
      rows, _ = instance.generate_rows(cat_with_nil, default_opts)
      expect(rows[0]).to include(nil)
    end

    it 'handles missing keys' do
      cat_missing = double('Category',
                           id: 'test',
                           cfgs: [
                             { env: 'TEST', desc: 'Desc', warning: nil }
                           ])
      rows, _ = instance.generate_rows(cat_missing, default_opts)
      expect(rows[0].size).to eq(4)
    end
  end

  describe '#wrap_row_values' do
    let(:rows) do
      [
        ['VAR1', 'String', 'Description', 'value1'],
        ['VAR2', 'Integer', 'Desc 2', 'value2']
      ]
    end

    it 'returns rows unchanged if no wrappers' do
      wrapped = instance.wrap_row_values(rows, {})
      expect(wrapped).to eq(rows)
    end

    it 'wraps values at specified indices' do
      wrappers = { 0 => '`', 3 => '*' }
      wrapped = instance.wrap_row_values(rows, wrappers)
      expect(wrapped[0][0]).to eq('`VAR1`')
      expect(wrapped[0][3]).to eq('*value1*')
    end

    it 'does not wrap nil values' do
      rows = [['VAR1', nil, 'Desc', 'value1']]
      wrappers = { 0 => '`', 1 => '`' }
      wrapped = instance.wrap_row_values(rows, wrappers)
      expect(wrapped[0][0]).to eq('`VAR1`')
      expect(wrapped[0][1]).to be_nil
    end

    it 'uses custom wrapper strings' do
      rows = [['VAR1', 'String']]
      wrappers = { 0 => '```', 1 => '**' }
      wrapped = instance.wrap_row_values(rows, wrappers)
      expect(wrapped[0][0]).to eq('```VAR1```')
      expect(wrapped[0][1]).to eq('**String**')
    end

    it 'handles wrapper for each row' do
      wrappers = { 0 => '`' }
      wrapped = instance.wrap_row_values(rows, wrappers)
      expect(wrapped[0][0]).to eq('`VAR1`')
      expect(wrapped[1][0]).to eq('`VAR2`')
    end

    it 'wraps multiple columns' do
      wrappers = { 0 => '`', 2 => '_' }
      wrapped = instance.wrap_row_values(rows, wrappers)
      expect(wrapped[0][0]).to eq('`VAR1`')
      expect(wrapped[0][2]).to eq('_Description_')
    end
  end

  describe '#process_warnings' do
    let(:rows) do
      [
        ['VAR1', 'String', 'Description', 'value1'],
        ['VAR2', 'Integer', 'Desc 2', 'value2'],
        ['VAR3', 'Boolean', 'Desc 3', 'value3']
      ]
    end

    context 'with inline mode' do
      let(:warning_opts) { { column_index: 2, mode: :inline } }

      it 'does not modify rows without warnings' do
        category_no_warn = double('Category',
                                  id: 'test',
                                  cfgs: [
                                    { env: 'VAR1', warning: nil },
                                    { env: 'VAR2', warning: nil },
                                    { env: 'VAR3', warning: nil }
                                  ])
        processed, _ = instance.process_warnings(rows, category_no_warn, warning_opts)
        expect(processed).to eq(rows)
      end

      it 'adds inline warning to rows with warnings' do
        processed, _ = instance.process_warnings(rows, category, warning_opts)
        expect(processed[1][2]).to include('⚠️')
        expect(processed[1][2]).to include('**Be careful**')
      end

      it 'adds line break before warning' do
        processed, _ = instance.process_warnings(rows, category, warning_opts)
        expect(processed[1][2]).to match(/<br>⚠️.*Be careful/)
      end

      it 'maintains other rows unchanged' do
        processed, _ = instance.process_warnings(rows, category, warning_opts)
        expect(processed[0]).to eq(rows[0])
        expect(processed[2]).to eq(rows[2])
      end

      it 'handles warning with markdown special characters' do
        cat_with_special = double('Category',
                                   id: 'test',
                                   cfgs: [
                                     { env: 'VAR1', _class: 'String', desc: 'Desc 1', default: 'val1', warning: nil },
                                     { env: 'VAR2', _class: 'String', desc: 'Desc 2', default: 'val2', warning: 'Warning **with** chars' }
                                   ])
        custom_rows = [
          ['VAR1', 'String', 'Desc 1', 'val1'],
          ['VAR2', 'String', 'Desc 2', 'val2']
        ]
        processed, _ = instance.process_warnings(custom_rows, cat_with_special, warning_opts)
        expect(processed[1][2]).to include('⚠️ **Warning **with** chars**')
      end
    end

    context 'with footnote mode' do
      let(:warning_opts) { { column_index: 2, mode: :footnote } }

      it 'generates footnotes' do
        processed, footnotes = instance.process_warnings(rows, category, warning_opts)
        expect(footnotes.size).to eq(1)
        expect(footnotes[0]).to include('[^test_1]:')
        expect(footnotes[0]).to include('Be careful')
      end

      it 'adds footnote reference to row' do
        processed, _ = instance.process_warnings(rows, category, warning_opts)
        expect(processed[1][2]).to include('[^test_1]')
      end

      it 'numbers footnotes incrementally' do
        cat_multiple_warn = double('Category',
                                   id: 'test',
                                   cfgs: [
                                     { env: 'VAR1', warning: nil },
                                     { env: 'VAR2', warning: 'Warning 1' },
                                     { env: 'VAR3', warning: 'Warning 2' }
                                   ])
        processed, footnotes = instance.process_warnings(rows, cat_multiple_warn, warning_opts)
        expect(footnotes.size).to eq(2)
        expect(processed[1][2]).to include('[^test_1]')
        expect(processed[2][2]).to include('[^test_2]')
      end

      it 'includes category id in footnote id' do
        processed, footnotes = instance.process_warnings(rows, category, warning_opts)
        expect(footnotes[0]).to match(/\[\^test_\d+\]/)
      end
    end

    context 'without warning options' do
      it 'returns rows unchanged' do
        processed, footnotes = instance.process_warnings(rows, category, nil)
        expect(processed).to eq(rows)
        expect(footnotes).to eq([])
      end

      it 'returns rows unchanged when column_index is missing' do
        processed, footnotes = instance.process_warnings(rows, category, { mode: :inline })
        expect(processed).to eq(rows)
        expect(footnotes).to eq([])
      end
    end

    context 'with default mode (footnote)' do
      it 'defaults to footnote mode when mode is not specified' do
        warning_opts = { column_index: 2 }
        processed, footnotes = instance.process_warnings(rows, category, warning_opts)
        expect(footnotes.size).to eq(1)
        expect(processed[1][2]).to include('[^test_1]')
      end
    end
  end

  describe '#generate_table' do
    let(:headers) { ['Name', 'Type', 'Description', 'Default'] }
    let(:rows) do
      [
        ['VAR1', 'String', 'Desc 1', 'value1'],
        ['VAR2', 'Integer', 'Desc 2', 'value2'],
        ['LONG_VAR_NAME', 'Boolean', 'A very long description that exceeds', 'false']
      ]
    end

    it 'calculates column widths correctly' do
      table_lines = instance.generate_table(headers, {}, rows)
      expect(table_lines.size).to eq(5)
    end

    it 'generates header row' do
      table_lines = instance.generate_table(headers, {}, rows)
      expect(table_lines[0]).to include('Name')
      expect(table_lines[0]).to include('Type')
    end

    it 'generates separator row' do
      table_lines = instance.generate_table(headers, {}, rows)
      expect(table_lines[1]).to match(/^\|[-|]+\|$/)
    end

    it 'generates data rows' do
      table_lines = instance.generate_table(headers, {}, rows)
      expect(table_lines[2]).to include('VAR1')
      expect(table_lines[3]).to include('VAR2')
    end

    it 'left aligns by default' do
      table_lines = instance.generate_table(headers, {}, rows)
      header_line = table_lines[0]
      expect(header_line).to include('Name')
    end

    context 'with left alignment' do
      it 'adds left alignment marker' do
        alignments = { 0 => :left }
        table_lines = instance.generate_table(headers, alignments, rows)
        expect(table_lines[1]).to match(/:---/)
      end
    end

    context 'with right alignment' do
      it 'adds right alignment marker' do
        alignments = { 0 => :right }
        table_lines = instance.generate_table(headers, alignments, rows)
        expect(table_lines[1]).to match(/---:/)
      end
    end

    context 'with center alignment' do
      it 'adds center alignment marker' do
        alignments = { 0 => :center }
        table_lines = instance.generate_table(headers, alignments, rows)
        expect(table_lines[1]).to match(/:-+:|/)
      end

      it 'handles center alignment for short columns' do
        alignments = { 0 => :center }
        table_lines = instance.generate_table(['A', 'B'], alignments, [['C', 'D']])
        expect(table_lines[1]).to match(/:-+:|/)
      end
    end

    context 'with multiple alignments' do
      it 'applies different alignments to different columns' do
        headers = ['Name', 'Type', 'Value']
        alignments = { 0 => :left, 1 => :right, 2 => :center }
        table_lines = instance.generate_table(headers, alignments, [['A', 'B', 'C']])
        expect(table_lines[1]).to match(/:-+\|/)
        expect(table_lines[1]).to match(/-+:\|/)
        expect(table_lines[1]).to match(/:-+:|/)
      end
    end

    it 'handles empty rows array' do
      table_lines = instance.generate_table(headers, {}, [])
      expect(table_lines.size).to eq(2)
      expect(table_lines[0]).to include('Name')
      expect(table_lines[1]).to match(/^\|[-|]+\|$/)
    end

    it 'handles empty headers' do
      table_lines = instance.generate_table([], {}, [['A', 'B']])
      expect(table_lines.size).to eq(3)
      expect(table_lines[2]).to include('A')
      expect(table_lines[2]).to include('B')
    end

    it 'handles rows with nil values' do
      table_lines = instance.generate_table(headers, {}, [['A', nil, 'C', nil]])
      expect(table_lines[2]).to include('A')
      expect(table_lines[2]).to include('C')
    end

    it 'handles rows with long values' do
      long_desc = 'A very long description that exceeds the normal column width'
      table_lines = instance.generate_table(headers, {}, [['A', 'B', long_desc, 'D']])
      expect(table_lines[2]).to include(long_desc)
    end

    it 'converts values to strings for length calculation' do
      table_lines = instance.generate_table(headers, {}, [[123, 456.78, true, false]])
      expect(table_lines[2]).to include('123')
      expect(table_lines[2]).to include('456.78')
      expect(table_lines[2]).to include('true')
      expect(table_lines[2]).to include('false')
    end

    it 'adds proper spacing around values' do
      table_lines = instance.generate_table(headers, {}, [['A', 'B']])
      expect(table_lines[2]).to include('A')
      expect(table_lines[2]).to include('B')
      expect(table_lines[2]).to match(/\| A +\| B +\|/)
    end

    it 'handles mixed alignments' do
      alignments = {
        0 => :left,
        1 => :right,
        2 => :center,
        3 => nil
      }
      table_lines = instance.generate_table(headers, alignments, rows)
      expect(table_lines[1]).to match(/:-+:|/)
    end

    it 'creates table from arrays with different widths than headers' do
      small_rows = [['A', 'B', 'C']]
      expect { instance.generate_table(headers, {}, small_rows) }.not_to raise_error
    end
  end
end
