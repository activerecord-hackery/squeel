require 'polyamorous'

module Squeel
  module Adapters
    module ActiveRecord
      module JoinDependencyExtensions

        def self.included(base)
          base.class_eval do
            alias_method_chain :build, :squeel
          end
        end

        def build_with_squeel(associations, parent = nil, join_type = Arel::InnerJoin)
          case associations
          when Nodes::Stub
            associations = associations.symbol
          when Nodes::Join
            associations = associations._join
          end

          if Nodes::KeyPath === associations
            parent ||= _join_parts.last
            associations.path.each do |key|
              parent = build(key, parent, join_type)
            end
            parent
          else
            build_without_squeel(associations, parent, join_type)
          end
        end

      end
    end
  end
end
