require 'squeel/adapters/active_record/4.1/join_dependency_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module JoinDependencyExtensions
        def make_joins(parent, child)
          tables    = child.tables
          info      = make_constraints parent, child, tables, child.join_type || Arel::Nodes::InnerJoin

          [info] + child.children.flat_map { |c| make_joins(child, c) }
        end
      end
    end
  end
end
