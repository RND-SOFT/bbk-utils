require 'securerandom'

module BBK
  module Smev3
    MTOM_ID_FIRST_LETTERS = %w[a b c d e f].freeze

    ##
    # Метод для генерации идентификатора вложения подставляемого сервисом в xml вида сведений.
    # Который затем в сервисе smev3 будет заменен на реальный идентификатор вложения в ftp хранилище.
    def self.build_attachment_id(id)
      "@{#{id}}"
    end

    # Создает attachment_id который можно указывать в AttachmentContent в качестве идентификатора
    def self.build_mtom_attachment_id
      id = SecureRandom.uuid
      id[0] = MTOM_ID_FIRST_LETTERS.sample
      id
    end

    def self.build_incoming_type(name, href)
      href_uri = URI.parse(href)
      # href_slug = [href_uri.scheme, href_uri.host, *href_uri.path.gsub('.', '-').split('/')].select(&:present?).join('-')
      href_slug = [href_uri.scheme, href_uri.host, *href_uri.path.split('/'), href_uri.query].select(&:present?).join('-').gsub(/[\.&]/, '-')
      Russian.translit "#{name}_#{href_slug}"
    end
  end
end
