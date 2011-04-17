module Squeel
  module Adapters
    module ActiveRecord
      module Preloader

        def self.included(base)
          base.class_eval do
            alias_method_chain :run, :squeel
          end
        end

        def run_with_squeel
          unless records.empty?
            Visitors::SymbolVisitor.new.accept(associations).each { |association| preload(association) }
          end
        end

      end
    end
  end
end