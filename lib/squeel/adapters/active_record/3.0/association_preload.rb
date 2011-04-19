module Squeel
  module Adapters
    module ActiveRecord
      module AssociationPreload

        def preload_associations(records, associations, preload_options={})
          records = Array.wrap(records).compact.uniq
          return if records.empty?
          super(records, Visitors::SymbolVisitor.new.accept(associations), preload_options)
        end

      end
    end
  end
end