# frozen_string_literal: true

module BBK
  module Utils
    class Config

      attr_accessor :store, :name

      class BooleanCaster

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

        def self.cast(value)
          if value.nil? || value == ''
            nil
          else
            !FALSE_VALUES.include?(value)
          end
        end

      end

      def self.instance
        @instance ||= new
      end

      class << self

        delegate :map, :require, :optional, :run!, :[], :[]=, :content, :to_s, :to_json, :as_json, :to_yaml, :fetch,
                 to: :instance

      end

      def initialize(name = nil)
        @name = name
        @store = {}
      end

      def map(env, file, required: true, desc: nil, bool: false, key: nil)
        @store[env.to_s.upcase] = {
          env:      (key || env).to_s.upcase,
          file:     file,
          required: required,
          desc:     desc,
          bool:     bool,
          type:     nil
        }
      end

      def require(env, desc: nil, bool: false, type: nil, key: nil)
        raise ArgumentError.new('Specified type and bool') if bool && type.present?

        type = BBK::Config::BooleanCaster.singleton_method(:cast) if bool
        @store[env.to_s.upcase] = {
          env:      (key || env).to_s.upcase,
          file:     nil,
          required: true,
          desc:     desc,
          bool:     bool,
          type:     type
        }
      end

      def optional(env, default: nil, desc: nil, bool: false, type: nil, key: nil)
        raise ArgumentError.new('Specified type and bool') if bool && type.present?

        type = BBK::Utils::Config::BooleanCaster.singleton_method(:cast) if bool
        @store[env.to_s.upcase] = {
          env:      (key || env).to_s.upcase,
          file:     nil,
          required: false,
          default:  default,
          desc:     desc,
          bool:     true,
          type:     type
        }
      end

      def run!(source = ENV)
        @store.each_value do |item|
          process(source, item)
        end
      end

      def [](key)
        @store[normalize_key(key)][:value]
      end

      def []=(key, value)
        @store[normalize_key(key)][:value] = value
      end

      def content(key)
        item = @store[normalize_key(key)]
        if (file = item[:file])
          File.read(file)
        else
          item[:value]
        end
      end

      def fetch(key, default = nil)
        # store.fetch(key.to_s.upcase, default)
        if (field = store[key.to_s.upcase]).present? && field.key?(:value)
          field[:value]
        else
          default
        end
      end

      def to_s
        result = StringIO.new
        result.puts "Environment variables#{@name ? " for #{@name}" : ''}:"
        padding = ' ' * 3
        sorted = @store.values.sort_by do |item|
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

      def as_json(*_args)
        values = @store.values.sort_by do |item|
          [item[:file].present? ? 0 : 1, item[:required] ? 0 : 1]
        end.reduce({}) do |ret, item|
          ret.merge(item[:env] => item)
        end

        @name ? { @name => values } : values
      end

      def to_json(*_args)
        JSON.pretty_generate(as_json)
      end

      def to_yaml(*_args)
        JSON.parse(to_json).to_yaml
      end

      private

        def normalize_key(key)
          k = key.to_s.upcase
          raise "There is no such key: #{k} in config!" unless @store.key?(k)

          k
        end

        def process(source, item)
          content = source.fetch(item[:env], item[:default])

          # ???????? ???????????? ????????, ???????? ???????????? ?????? (?????????? ?????? ???????? ?????????? ???????????????????? ???????? ?????????????? ????????)
          if content.present? || item[:type].present?
            if file = item[:file]
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
            item[:value] = content
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

        def required!(item)
          raise "ENV [#{item[:env]}] is required!"
        end

        def print_file_item(item, padding)
          line = "#{padding}File #{wrap_required(item)}"
          line = if item[:desc].present?
            "#{line.ljust(50)} #{item[:desc]}"
          else
            line
          end

          "#{line}\n#{padding * 2}-> #{item[:file].inspect}"
        end

        def print_item(item, padding)
          line = padding + wrap_required(item)
          line += " (=#{item[:default]})" if item[:default].present?

          line = if item[:desc].present?
            "#{line.ljust(50)} #{item[:desc]}"
          else
            line
          end

          "#{line}\n#{padding * 2}-> #{item[:value].inspect}"
        end

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

