module Squeel
  module Nodes
    # Defines Predicate factories named for each of the Arel predication methods
    module PredicateMethods

      (Constants::PREDICATES - [:eq]).each do |method_name|
        class_eval <<-RUBY
          def #{method_name}(value = :__undefined__)
            Nodes::Predicate.new self, :#{method_name}, value
          end
        RUBY
      end

      # YAY WHERECHAIN
      def eq(value = :__undefined__)
        if :chain == value
          false
        else
          Nodes::Predicate.new self, :eq, value
        end
      end

    end
  end
end
