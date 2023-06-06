# frozen_string_literal: true

require 'logger'

module BBK
  module Utils
    class CombinedLogger

      include ::Logger::Severity

      attr_reader :loggers, :progname, :level, :formatter

      def self.new(*args, **kwargs)
        ActiveSupport::TaggedLogging.new(super)
      end

      def initialize(progname, *loggers, formatter: LogFormatter.new, level: Logger::Severity::INFO)
        @loggers = loggers
        self.progname = progname
        self.level = level
        self.formatter = formatter
      end

      def progname=(name)
        @progname = name
        @loggers.each {|logger| logger.progname = name}
      end
  
      def formatter=(formatter)
        @formatter = formatter
        @loggers.each {|logger| logger.formatter = formatter}
      end
  
      def level=(level)
        log_level = if  level.is_a?(Integer) || (Integer(level) rescue false)
          level
        else
          self.class.const_get(level.to_s.upcase)
        end
        @level = log_level
        @loggers.each {|logger| logger.level = log_level }
      end

      alias sev_threshold level
      alias sev_threshold= level=    
  
      %i[debug info warn error fatal].each do |level|
        define_method(level) do |*args, &block|
          loggers.each {|logger| logger.send(level, *args, &block)}
          nil
        end

        define_method("#{level}?") do
          self.level <= self.class.const_get(level.upcase.to_sym)
        end

        define_method("#{level}!") do
          self.level = self.class.const_get(level.upcase.to_sym)
        end

      end

      def method_missing(name, *args, **kwargs, &block)
        @loggers.each {|logger| logger.send(name, *args, **kwargs, &block)}
        nil
      end
  
      def clone
        super.tap do |it| 
          it.instance_variable_set(:@loggers, loggers.map(&:clone)) 
        end 
      end

    end
  end
end