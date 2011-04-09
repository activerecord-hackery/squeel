module Squeel
  module PredicateMethods
    module Function
      def predicate(method_name, value = :__undefined__)
        Nodes::Predicate.new self, method_name, value
      end
    end
  end
end