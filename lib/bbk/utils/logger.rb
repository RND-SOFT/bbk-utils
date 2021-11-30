# frozen_string_literal: true

require 'logger'
require 'active_support/tagged_logging'
require 'bbk/utils/log_formatter'

module BBK
  class Logger < ::Logger
    DEFAULT_NAME = 'bbk'
    DEFAULT_LEVEL = Logger::Severity::DEBUG

    def self.new(*args)
      instance = super
      ActiveSupport::TaggedLogging.new(instance)
    end

    def initialize(progname, level, io: STDOUT)
      io.sync = true
      super(io)
      self.progname = progname

      if level.is_a?(Integer)
        self.level = level
      else
        level = level.to_s.upcase
        level = level.present? ? level : 'INFO'
        self.level = Logger.const_get(level)
      end

      self.formatter = LogFormatter.new
      info "Using LOG_LEVEL=#{level}"
    end

    def silence(*_args)
      yield self
    end

    def self.default
      if @default
        @default
      else
        @default = new(DEFAULT_NAME, 'UNKNOWN')
        @default.level = DEFAULT_LEVEL
        @default
      end
    end
  end
end