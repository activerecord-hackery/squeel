module Squeel
  module Adapters
    module ActiveRecord
      module BaseExtensions

        def squeel(&block)
          DSL.eval &block
        end

        def sifter(name = nil)
          if Symbol === name && block_given?
            singleton_class.send :define_method, name,
                                  lambda {|*args| DSL.exec(*args, &Proc.new)}
          else
            raise ArgumentError, "A name and block are required"
          end
        end

        def build_default_scope_with_squeel #:nodoc:
          if defined?(::ActiveRecord::Scoping) &&
            method(:default_scope).owner != ::ActiveRecord::Scoping::Default::ClassMethods
            evaluate_default_scope { default_scope }
          elsif default_scopes.any?
            evaluate_default_scope do
              default_scopes.inject(relation) do |default_scope, scope|
                if scope.is_a?(Hash)
                  default_scope.apply_finder_options(scope)
                elsif !scope.is_a?(::ActiveRecord::Relation) && scope.respond_to?(:call)
                  default_scope.merge(scope.call, true)
                else
                  default_scope.merge(scope, true)
                end
              end
            end
          end
        end

      end
    end
  end
end
