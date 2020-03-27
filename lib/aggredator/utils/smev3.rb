module Aggredator

    module Smev3
    
      ##
      # Метод для генерации идентификатора вложения подставляемого сервисом в xml вида сведений.
      # Который затем в сервисе smev3 будет заменен на реальный идентификатор вложения в ftp хранилище.
      def self.build_attachment_id(id)
        "@{#{id}}"
      end

    end

end