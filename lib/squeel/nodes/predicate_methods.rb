module Squeel
  module Nodes
    # Defines Predicate factories named for each of the ARel predication methods
    module PredicateMethods

      Constants::PREDICATES.each do |method_name|
        class_eval <<-RUBY
          def #{method_name}(value = :__undefined__)
            Nodes::Predicate.new self, :#{method_name}, value
          end
        RUBY
      end

    end
  end
end
