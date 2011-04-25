require 'squeel/nodes/binary'

module Squeel
  module Nodes
    # A node representing an SQL OR, which will result in same when visited.
    class Or < Binary
    end
  end
end