module Squeel
  module Nodes
    class Sifter
      include PredicateOperators

      attr_reader :name, :args

      def initialize(name, args)
        @name, @args = name, args
      end

    end
  end
end