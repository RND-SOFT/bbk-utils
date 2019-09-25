module Aggredator

  class Config

    attr_accessor :store, :name
  
    def self.instance
      @instance ||= self.new
    end
  
    class << self
  
      delegate :map, :require, :optional, :run!, :[], :[]=, :content, :to_s, :to_json, :as_json, :to_yaml, to: :instance
  
    end
  
    def initialize(name = nil)
      @name = name
      @store = {}
    end
  
    def map(env, file, required: true, desc: nil, bool: false)
      @store[env.to_s.upcase] = {
        env:      env.to_s.upcase,
        file:     file,
        required: required,
        desc:     desc,
        bool:     bool
      }
    end
  
    def require(env, desc: nil, bool: false, type: nil)
      @store[env.to_s.upcase] = {
        env:      env.to_s.upcase,
        required: true,
        desc:     desc,
        bool:     bool,
        type:     type
      }
    end
  
    def optional(env, default: nil, desc: nil, bool: false, type: nil)
      @store[env.to_s.upcase] = {
        env:      env.to_s.upcase,
        required: false,
        default:  default,
        desc:     desc,
        bool:     bool,
        type:     type
      }
    end
  
    def run!(source = ENV)
      @store.values.each do |item|
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
      if file = item[:file]
        File.read(file)
      else
        item[:value]
      end
    end
  
    def self.fetch(key, default = nil)
      instance.store.fetch(key.to_s.upcase, default)
    end
  
    def to_s
      result = StringIO.new
      result.puts "Environment variables#{@name ? " for #{@name}" : ''}:"
      padding = ' ' * 3
      sorted = @store.values.sort_by {|item| [item[:file].present? ? 0 : 1, item[:required] ? 0 : 1] }
  
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
  
        if content.present?
          if file = item[:file]
            dirname = File.dirname(file)
            FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
            File.write(file, content)
            item[:value] = file
          else
            item[:value] = if item[:bool]
              ActiveRecord::Type::Boolean.new.cast(content || false)
            elsif type = item[:type]
              if type.respond_to? :call
                type.call(content)
              else
                type.new(content)
              end
            else
              content
            end
          end
        else
          required!(item) if item[:required]
        end
      end
  
      def required!(item)
        raise "ENV [#{item[:env]}] is required!"
      end
  
      def print_file_item(item, padding)
        line = padding + 'File ' + wrap_required(item)
        line = line.ljust(30) + '-> ' + "\"#{item[:file]}\""
        if item[:desc].present?
          line.ljust(50) + ' ' + item[:desc]
        else
          line
        end
      end
  
      def print_item(item, padding)
        line = padding + wrap_required(item)
        line += " (=#{item[:default]})" if item[:default].present?
  
        if item[:desc].present?
          line.ljust(50) + ' ' + item[:desc]
        else
          line
        end
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
