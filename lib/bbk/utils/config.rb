# frozen_string_literal: true

module BBK
  module Utils
    class Config

      PREFIX_SEP = '_'.freeze

      attr_accessor :store, :name
      attr_reader :prefix, :env_prefix, :parent

      class KeyError < StandardError; end

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

      def self.instance(prefix: nil)
        @instance ||= new(prefix: prefix)
      end

      class << self

        delegate :map, :require, :optional, :run!, :[], :[]=, :content, :to_s, :to_json, :as_json, :to_yaml, :fetch,
                 to: :instance

      end

      def initialize(name: nil, prefix: nil, parent: nil)
        @name = name
        @store = {}
        @parent = parent
        @subconfigs = []
        @prefix = normalize_key(prefix)
        @prefixes = if parent.nil?
          [@prefix]
        else
          parent.prefixes.dup + [@prefix]
        end.compact
        @env_prefix = normalize_key(@prefixes.join(PREFIX_SEP))
      end

      def map(env, file, required: true, desc: nil, bool: false, key: nil)
        @store[full_prefixed_key(env)] = {
          env:      full_prefixed_key(key || env),
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
        @store[full_prefixed_key(env)] = {
          env:      full_prefixed_key(key || env),
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
        @store[full_prefixed_key(env)] = {
          env:      full_prefixed_key(key || env),
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
        @subconfigs.each {|sub| sub.run!(source)}
        nil
      end

      def subconfig(prefix: , name: nil)
        raise ArgumentError.new("Subconfig with prefix #{prefix} already exists") if @subconfigs.any? {|sub| sub.prefix == prefix.to_s }
        sub = self.class.new(name: name, prefix: prefix, parent: self)
        @subconfigs << sub
        if block_given?
          yield sub
        end
        sub
      end

      def [](key)
        self.get(key, search_up: true, search_down: true)[:value]
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
        if (rec = self.get(key, search_up: true, search_down: true)) && rec.key?(:value)
          rec[:value]
        else
          default
        end
      rescue KeyError
        default
      end

      def to_s
        result = StringIO.new
        result.puts "Environment variables#{@name ? " for #{@name}" : ''}:"
        padding = ' ' * 3
        sorted = store_with_subconfigs.values.sort_by do |item|
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
        values = store_with_subconfigs.values.sort_by do |item|
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

      def root?
        @parent.nil?
      end

      protected

      def prefixes
        @prefixes
      end

      def get(key, search_up: false, search_down: false)
        normalized_key = normalize_key(key)
        if @store.key?(normalized_key)
          return @store[normalized_key]
        end
        prefix_key = full_prefixed_key(key)
        if @store.key?(prefix_key)
          return @store[prefix_key]
        end
        if search_down
          sub_prefixed_keys(key).each do |pref_key|
            if @store.key?(pref_key)
              return @store[pref_key]
            end

            subconf = @subconfigs.find {|sub| pref_key.starts_with?(sub.env_prefix)}
            next if subconf.nil?
            return subconf.get(pref_key, search_up: false, search_down: true)
          end
        end
        if search_up && @parent
          return @parent.get(key, search_up: true, search_down: false)
        end
        raise KeyError.new("There is no such key: #{key} in config!")
      end

      def store_with_subconfigs
        res = @store.dup
        @subconfigs.each do |sub|
          res = res.merge(sub.store_with_subconfigs)
        end
        res
      end

      private

        def normalize_key(key)
          return nil if key.nil?
          key.to_s.upcase
        end

        def full_prefixed_key(key)
          p_key = if env_prefix.empty?
            [key.to_s]
          else
            [env_prefix, key.to_s]
          end.join(PREFIX_SEP)
          normalize_key(p_key)
        end

        def sub_prefixed_keys(key)
          Enumerator.new do |yielder|
            @prefixes.size.downto(0).each do |last_index|
              yielder << [*@prefixes[0...last_index], normalize_key(key)].compact.join(PREFIX_SEP)
            end
          end
        end

        def process(source, item)
          content = source.fetch(item[:env], item[:default])

          # Если данные есть, либо указан тип (нужно для того чтобы переменная была нужного типа)
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

