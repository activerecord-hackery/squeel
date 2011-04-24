require 'squeel/nodes/predicate_operators'

# Hashes are "acceptable" by PredicateVisitor, so they
# can be treated like nodes for the purposes of and/or/not
# if you load these extensions.
#
# @example Load Hash extensions
#   Squeel.configure do |config|
#     config.load_core_extensions :hash
#   end
class Hash
  include Squeel::Nodes::PredicateOperators
end