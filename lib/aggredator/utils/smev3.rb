module Aggredator

    module Smev3
    
      ##
      # Метод для генерации идентификатора вложения подставляемого сервисом в xml вида сведений.
      # Который затем в сервисе smev3 будет заменен на реальный идентификатор вложения в ftp хранилище.
      def self.build_attachment_id(id)
        "@{#{id}}"
      end

      def self.build_incoming_type(name, href)
        href_uri = URI.parse(href)
        href_slug = [href_uri.scheme, href_uri.host, *href_uri.path.gsub('.', '-').split('/')].select(&:present?).join('-')  
        "#{name}_#{href_slug}"
      end

    end

end