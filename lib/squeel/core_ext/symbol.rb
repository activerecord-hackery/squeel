# These extensions to Symbol are loaded optionally, mostly to provide
# a small amount of backwards compatibility with MetaWhere.
#
# @example Load Symbol extensions
#   Squeel.configure do |config|
#     config.load_core_extensions :symbol
#   end
class Symbol
  include Squeel::Nodes::PredicateMethods
  include Squeel::Nodes::Aliasing
  include Squeel::Nodes::Ordering

  def func(*args)
    Squeel::Nodes::Function.new(self, args)
  end

  def inner
    Squeel::Nodes::Join.new(self, Squeel::InnerJoin)
  end

  def outer
    Squeel::Nodes::Join.new(self, Squeel::OuterJoin)
  end

  def of_class(klass)
    Squeel::Nodes::Join.new(self, Squeel::InnerJoin, klass)
  end

end
