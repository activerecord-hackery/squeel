module Squeel
  module Adapters
    module ActiveRecord
      module PreloaderExtensions

        def self.included(base)
          base.class_eval do
            alias_method_chain :preload, :squeel
          end
        end

        def preload_with_squeel(records, associations, preload_scope = nil)
          records       = Array.wrap(records).compact.uniq
          associations  = Array.wrap(associations)
          preload_scope = preload_scope || ::ActiveRecord::Associations::Preloader::NULL_RELATION

          if records.empty?
            []
          else
            Visitors::PreloadVisitor.new.accept(associations).flat_map do |association|
              preloaders_on(association, records, preload_scope)
            end
          end
        end

      end
    end
  end
end

ActiveRecord::Associations::Preloader.send :include, Squeel::Adapters::ActiveRecord::PreloaderExtensions
