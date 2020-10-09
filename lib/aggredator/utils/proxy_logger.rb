# frozen_string_literal: true

require 'aggredator/utils/logger'

module Aggredator
  class ProxyLogger
    attr_reader :tags, :logger

    def initialize(logger, tags:)
      @logger = logger
      @tagged = @logger.respond_to?(:tagged)
      @tags = [tags].flatten
    end

    def add_tags(*tags)
      @tags += tags.flatten
      @tags = @tags.uniq
    end

    def method_missing(method, *args, &block)
      super unless logger.respond_to?(method)

      if @tagged
        current_tags = tags - logger.formatter.current_tags
        logger.tagged(current_tags) { logger.send(method, *args, &block) }
      else
        logger.send(method, *args, &block)
      end
    end

    def respond_to?(*args)
      logger.send(:respond_to?, *args) || super
    end

    def respond_to_missing?(method_name, include_private = false)
      logger.send(:respond_to_missing?, method_name, include_private) || super
    end
  end
end
