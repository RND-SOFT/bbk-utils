# frozen_string_literal: true

require 'logger'

module BBK
  module Utils
    class LogFormatter < ::Logger::Formatter

      FORMAT = "%5s [%sUTC #%d] (%s)[%s]: %s\n"

      def initialize(tags: [], filter: nil)
        super()
        @tags = tags
        @filter = filter
      end

      def call(severity, time, progname, msg)
        msg = try_filtering(msg)
        line = msg2str(msg).gsub("\n", '\\n')
        line = "#{build_tags_text}#{line}"
        format(FORMAT, severity, format_datetime(time.utc), Process.pid, progname, thread_id, line)
      end

      def thread_id
        [
          Thread.current.object_id.to_s,
          Thread.current.name || thread_name_from_main
        ].compact.join('@')
      end

      def thread_name_from_main
        if Thread.main.name
          Thread.current[:bbk_thread_id] ||= "#{Thread.main.name}-#{Thread.current.object_id}"
        end
      end

      private

      def build_tags_text
        @tags.collect { "[#{_1}] " }.join if @tags.any?
      end

      def try_filtering(msg)
        return msg if @filter.nil?

        if msg.is_a?(Hash)
          @filter.filter(msg)
        elsif msg.respond_to?(:to_h)
          @filter.filter(msg.to_h)
        else
          msg
        end
      end

    end
  end
end
