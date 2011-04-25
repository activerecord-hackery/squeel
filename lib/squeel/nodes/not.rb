require 'squeel/nodes/unary'

module Squeel
  module Nodes
    # A node that represents SQL NOT, and will result in same when visited
    class Not < Unary
    end
  end
end