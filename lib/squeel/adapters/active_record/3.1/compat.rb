require 'squeel/adapters/active_record/compat'

module Arel
  module Visitors
    class ToSql < Arel::Visitors::Visitor

      def initialize pool
        @pool = pool
        @pool.with_connection { |conn| @connection = conn }
        @quoted_tables  = {}
        @quoted_columns = {}
      end

    end
  end
end
