require 'squeel/nodes/as'

module Squeel
  module Nodes
    module Aliasing

      def as(name)
        As.new(self, Arel.sql(name))
      end

    end
  end
end