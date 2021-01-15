require 'active_support/core_ext'
require 'russian'
require 'aggredator/utils/config'
require 'aggredator/utils/crypt'
require 'aggredator/utils/logger'
require 'aggredator/utils/proxy_logger'
require 'aggredator/utils/version'
require 'aggredator/utils/smev3'
require 'aggredator/utils/shared_store'
require 'aggredator/utils/env_helper'

module Aggredator
  module Utils
    class << self
      attr_accessor :logger

      def gracefully_main(&block)
        yield
        0
      rescue SignalException => e
        if %w[INT TERM EXIT QUIT].include?(Signal.signame(e.signo))
          0
        else
          logger.error "Signal: #{e.inspect}"
          1
        end
      rescue StandardError => e
        logger.error "Exception: #{e.inspect}. Backtrace: #{e.backtrace.inspect}"
        1
      end
  

    end

    self.logger = ::Logger.new(STDOUT)
  end
end
