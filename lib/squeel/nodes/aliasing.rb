require 'squeel/nodes/as'

module Squeel
  module Nodes
    module Aliasing

      def as(name)
        As.new(self, name.to_s)
      end

    end
  end
end