require 'spec_helper'

describe Symbol do
  describe '#asc' do
    it 'creates an ascending order node' do
      order = :blah.asc
      order.should be_a Squeel::Nodes::Order
      order.expr.should eq :blah
      order.should be_ascending
    end
  end

  describe '#desc' do
    it 'creates a descending order node' do
      order = :blah.desc
      order.should be_a Squeel::Nodes::Order
      order.expr.should eq :blah
      order.should be_descending
    end
  end

  describe '#func' do
    it 'creates a function node' do
      function = :blah.func('foo')
      function.should be_a Squeel::Nodes::Function
      function.function_name.should eq :blah
      function.args.should eq ['foo']
    end
  end

  describe '#inner' do
    it 'creates an inner join' do
      join = :blah.inner
      join.should be_a Squeel::Nodes::Join
      join._name.should eq :blah
      join._type.should eq Squeel::InnerJoin
    end
  end

  describe '#outer' do
    it 'creates an outer join' do
      join = :blah.outer
      join.should be_a Squeel::Nodes::Join
      join._name.should eq :blah
      join._type.should eq Squeel::OuterJoin
    end
  end

  describe '#of_class' do
    it 'creates an inner polymorphic join with the given class' do
      join = :blah.of_class(Person)
      join.should be_a Squeel::Nodes::Join
      join._name.should eq :blah
      join._type.should eq Squeel::InnerJoin
      join._klass.should eq Person
    end
  end
end
