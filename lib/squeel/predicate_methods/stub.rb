module Squeel
  module PredicateMethods
    module Stub
      def predicate(method_name, value = :__undefined__)
        Nodes::Predicate.new self.symbol, method_name, value
      end
    end
  end
end