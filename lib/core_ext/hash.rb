require 'squeel/nodes/predicate_operators'

class Hash
  # Hashes are "acceptable" by PredicateVisitor, so they
  # can be treated like nodes for the purposes of and/or/not
  # if you load core extensions with:
  #
  #   Squeel.configure do |config|
  #     config.load_core_extensions :hash
  #   end

  include Squeel::Nodes::PredicateOperators
end