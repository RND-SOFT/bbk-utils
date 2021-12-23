# frozen_string_literal: true

require 'securerandom'
require 'russian'

module BBK
  module Utils
    module Xml

      MTOM_ID_FIRST_LETTERS = %w[a b c d e f].freeze

      ##
      # Generate identifier to future substitution in XML body. Ex.: real attachment identifier when uploading to FTP
      def self.build_substitution_id(id)
        "@{#{id}}"
      end

      ##
      # Generate uuid compatible with SOAP AttachmentContent identifier
      def self.generate_mtom_attachment_id
        id = SecureRandom.uuid
        id[0] = MTOM_ID_FIRST_LETTERS.sample
        id
      end

      ##
      # Normalize XML href to be predictible and constant in various cases
      def self.normalize_slug(name, href)
        href_uri = URI.parse(href)
        href_slug = [href_uri.scheme, href_uri.host, *href_uri.path.split('/'), href_uri.query].select do |item|
          item.present?
        end.join('-').gsub(
          /[.&]/, '-'
        )
        Russian.translit "#{name}_#{href_slug}"
      end

    end
  end
end

