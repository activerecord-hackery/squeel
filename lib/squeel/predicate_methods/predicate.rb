module Squeel
  module PredicateMethods
    module Predicate
      def predicate(method_name, value = :__undefined__)
        @method_name = method_name
        @value = value unless value == :__undefined__
        self
      end
    end
  end
end