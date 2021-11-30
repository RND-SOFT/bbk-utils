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

    end

    self.logger = ::Logger.new(STDOUT)
  end
end
