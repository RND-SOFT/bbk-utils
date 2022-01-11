# frozen_string_literal: true

require 'logger'

module BBK
  module Utils
    class LogFormatter < ::Logger::Formatter

      FORMAT = "%5s [%sUTC #%d] (%s)[%s]: %s\n"
      def call(severity, time, progname, msg)
        line = msg2str(msg).gsub("\n", '\\n')
        format(FORMAT, severity, format_datetime(time.utc), Process.pid, progname, thread_id, line)
      end

      def thread_id
        [Thread.current.object_id.to_s, Thread.current.name].compact.join('@')
      end

    end
  end
end

