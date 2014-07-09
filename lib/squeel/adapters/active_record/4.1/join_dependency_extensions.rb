module Squeel
  module Adapters
    module ActiveRecord
      module JoinDependencyExtensions

        def self.included(base)
          base.extend ClassMethods
          base.class_eval do
            class << self
              alias_method_chain :walk_tree, :squeel
            end
            alias_method_chain :join_constraints, :squeel
          end
        end

        def join_constraints_with_squeel(outer_joins)
          joins = join_root.children.flat_map { |child|
            make_joins join_root, child
          }

          joins.concat outer_joins.flat_map { |oj|
            if join_root.match? oj.join_root
              walk join_root, oj.join_root
            else
              oj.join_root.children.flat_map { |child|
                make_outer_joins oj.join_root, child
              }
            end
          }
        end

        def make_joins(parent, child)
          tables    = child.tables
          joins     = make_constraints parent, child, tables, child.join_type || Arel::Nodes::InnerJoin

          joins.concat child.children.flat_map { |c| make_joins(child, c) }
        end

        private :make_joins

        module ClassMethods
          def walk_tree_with_squeel(associations, hash)
            case associations
            when Nodes::Stub
              hash[associations.symbol] ||= {}
            when Nodes::Join
              hash[associations._join] ||= {}
            when Nodes::KeyPath
              walk_through_path(associations.path.dup, hash)
            when Hash
              associations.each do |k, v|
                cache = case k
                when Nodes::Stub, Nodes::Join, Nodes::KeyPath
                    walk_tree(k, hash)
                  else
                    hash[k] ||= {}
                  end

                walk_tree(v, cache)
              end
            else
              walk_tree_without_squeel(associations, hash)
            end
          end

          private

            def walk_through_path(path, hash)
              cache = walk_tree(path.shift, hash)
              path.empty? ? cache : walk_through_path(path, cache)
            end
        end

      end

      JoinAssociation = ::ActiveRecord::Associations::JoinDependency::JoinAssociation
      JoinDependency = ::ActiveRecord::Associations::JoinDependency

      JoinDependency.send :include, Adapters::ActiveRecord::JoinDependencyExtensions

    end
  end
end
