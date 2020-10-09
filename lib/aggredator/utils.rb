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
    end

    self.logger = ::Logger.new(STDOUT)
  end
end
