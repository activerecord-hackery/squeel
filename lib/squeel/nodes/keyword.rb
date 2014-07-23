module Squeel
  module Nodes
    module Keyword

      KEYWORDS = {
        :_star => :*,
        :_not  => :NOT
      }

      def translate_keyword(method_id)
        KEYWORDS.fetch(method_id, method_id)
      end
    end
  end
end
