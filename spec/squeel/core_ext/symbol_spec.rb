require 'spec_helper'

describe Symbol do
  describe '#asc' do
    it 'creates an ascending order node' do
      order = :blah.asc
      expect(order).to be_a Squeel::Nodes::Order
      expect(order.expr).to eq :blah
      expect(order).to be_ascending
    end
  end

  describe '#desc' do
    it 'creates a descending order node' do
      order = :blah.desc
      expect(order).to be_a Squeel::Nodes::Order
      expect(order.expr).to eq :blah
      expect(order).to be_descending
    end
  end

  describe '#func' do
    it 'creates a function node' do
      function = :blah.func('foo')
      expect(function).to be_a Squeel::Nodes::Function
      expect(function.function_name).to eq :blah
      expect(function.args).to eq ['foo']
    end
  end

  describe '#inner' do
    it 'creates an inner join' do
      join = :blah.inner
      expect(join).to be_a Squeel::Nodes::Join
      expect(join._name).to eq :blah
      expect(join._type).to eq Squeel::InnerJoin
    end
  end

  describe '#outer' do
    it 'creates an outer join' do
      join = :blah.outer
      expect(join).to be_a Squeel::Nodes::Join
      expect(join._name).to eq :blah
      expect(join._type).to eq Squeel::OuterJoin
    end
  end

  describe '#of_class' do
    it 'creates an inner polymorphic join with the given class' do
      join = :blah.of_class(Person)
      expect(join).to be_a Squeel::Nodes::Join
      expect(join._name).to eq :blah
      expect(join._type).to eq Squeel::InnerJoin
      expect(join._klass).to eq Person
    end
  end
end
