require 'squeel/nodes/nary'

module Squeel
  module Nodes
    # A grouping of nodes that will be converted to an Arel::Nodes::And upon visitation.
    class And < Nary
    end
  end
end