# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'bbk/utils/config'
require 'bbk/utils/crypt'
require 'bbk/utils/logger'
require 'bbk/utils/proxy_logger'
require 'bbk/utils/version'
require 'bbk/utils/xml'
require 'bbk/utils/env_helper'

module BBK
  module Utils

    class << self

      attr_accessor :logger

      def gracefully_main
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
      rescue SystemExit => e
        logger.error "System exit: #{e.inspect}. Backtrace: #{e.backtrace.inspect}"
        e.status
      end

    end

    self.logger = ::BBK::Utils::Logger.default

  end
end

