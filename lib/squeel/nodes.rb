module Squeel
  # Namespace for the nodes created by Squeel::DSL, and
  # evaluated by Squeel::Visitors classes
  module Nodes
  end
end

require 'squeel/nodes/node'

require 'squeel/nodes/predicate_methods'
require 'squeel/nodes/operators'
require 'squeel/nodes/predicate_operators'
require 'squeel/nodes/aliasing'
require 'squeel/nodes/ordering'

require 'squeel/nodes/literal'
require 'squeel/nodes/stub'
require 'squeel/nodes/key_path'
require 'squeel/nodes/sifter'
require 'squeel/nodes/predicate'
require 'squeel/nodes/function'
require 'squeel/nodes/operation'
require 'squeel/nodes/order'
require 'squeel/nodes/and'
require 'squeel/nodes/or'
require 'squeel/nodes/as'
require 'squeel/nodes/not'
require 'squeel/nodes/join'
require 'squeel/nodes/grouping'
require 'squeel/nodes/subquery_join'
