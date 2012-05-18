require 'squeel/nodes/as'

module Squeel
  module Nodes
    module Aliasing

      def as(name)
        As.new(self, Arel.sql(name.to_s))
      end

    end
  end
end
