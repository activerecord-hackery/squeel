require 'squeel/adapters/active_record/context'

module Squeel
  module Adapters
    module ActiveRecord
      class Context < ::Squeel::Context

        private

        def get_arel_visitor
          Arel::Visitors.visitor_for @engine
        end

      end
    end
  end
end
