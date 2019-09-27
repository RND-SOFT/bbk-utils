require 'aggredator/utils/log_formatter'
require 'logger'

module Aggredator

  class Logger < ::Logger
    
    DEFAULT_NAME = 'aggredator'
    DEFAULT_LEVEL = 'DEBUG'

    def initialize(progname, level)
      STDOUT.sync = true
      super(STDOUT)
      self.progname = progname
  
      level = level.to_s.upcase
      level = level.present? ? level : 'INFO'
  
      self.level = Logger.const_get(level)
      self.formatter = LogFormatter.new
      info "Using LOG_LEVEL=#{level}"
    end
  
    def silence(*_args)
      yield self
    end

    def self.default
      @@default ||= self.new(DEFAULT_NAME, DEFAULT_LEVEL)
    end

  end

end


