module Squeel
  # Namespace for the nodes created by Squeel::DSL, and
  # evaluated by Squeel::Visitors classes
  module Nodes
  end
end
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