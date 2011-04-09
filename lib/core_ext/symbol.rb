require 'squeel/predicate_methods'

class Symbol
  # These extensions to Symbol are loaded optionally, with:
  #
  #   Squeel.configure do |config|
  #     config.load_core_extensions :symbol
  #   end

  include Squeel::PredicateMethods

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