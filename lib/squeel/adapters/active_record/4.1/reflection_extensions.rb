module Squeel
  module Adapters
    module ActiveRecord
      module ReflectionExtensions
        def self.included(base)
          base.extend ClassMethods
          base.class_eval do
            class << self
              alias_method_chain :reflect_on_aggregation, :squeel
              alias_method_chain :reflect_on_association, :squeel
              alias_method_chain :_reflect_on_association, :squeel
            end
          end
        end

        module ClassMethods
          def reflect_on_aggregation_with_squeel(aggregation)
            aggregation ||= ""
            reflect_on_aggregation_without_squeel(aggregation)
          end

          def reflect_on_association_with_squeel(association)
            association ||= ""
            reflect_on_association_without_squeel(association)
          end

          def _reflect_on_association_with_squeel(association)
            association ||= ""
            _reflect_on_association_without_squeel(association)
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Squeel::Adapters::ActiveRecord::ReflectionExtensions
