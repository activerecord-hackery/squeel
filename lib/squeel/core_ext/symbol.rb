require 'squeel/predicate_methods'
require 'squeel/nodes/aliasing'

# These extensions to Symbol are loaded optionally, mostly to provide
# a small amount of backwards compatibility with MetaWhere.
#
# @example Load Symbol extensions
#   Squeel.configure do |config|
#     config.load_core_extensions :symbol
#   end
class Symbol
  include Squeel::PredicateMethods
  include Squeel::Nodes::Aliasing

  def asc
    Squeel::Nodes::Order.new self, 1
  end

  def desc
    Squeel::Nodes::Order.new self, -1
  end

  def func(*args)
    Squeel::Nodes::Function.new(self, args)
  end

  def inner
    Squeel::Nodes::Join.new(self, Arel::InnerJoin)
  end

  def outer
    Squeel::Nodes::Join.new(self, Arel::OuterJoin)
  end

  def of_class(klass)
    Squeel::Nodes::Join.new(self, Arel::InnerJoin, klass)
  end

end