require 'spec_helper'

describe Symbol do

  Squeel::Constants::PREDICATES.each do |method_name|
    it "creates #{method_name} predicates with no value" do
      predicate = :attribute.send(method_name)
      predicate.expr.should eq :attribute
      predicate.method_name.should eq method_name
      predicate.value?.should be_false
    end

    it "creates #{method_name} predicates with a value" do
      predicate = :attribute.send(method_name, 'value')
      predicate.expr.should eq :attribute
      predicate.method_name.should eq method_name
      predicate.value.should eq 'value'
    end
  end

  Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
    aliases.each do |aliaz|
      ['', '_any', '_all'].each do |suffix|
        it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
          predicate = :attribute.send(aliaz.to_s + suffix)
          predicate.expr.should eq :attribute
          predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
          predicate.value?.should be_false
        end

        it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
          predicate = :attribute.send((aliaz.to_s + suffix), 'value')
          predicate.expr.should eq :attribute
          predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
          predicate.value.should eq 'value'
        end
      end
    end
  end

  it 'creates ascending orders' do
    order = :attribute.asc
    order.should be_ascending
  end

  it 'creates descending orders' do
    order = :attribute.desc
    order.should be_descending
  end

  it 'creates functions' do
    function = :function.func
    function.should be_a Squeel::Nodes::Function
  end

  it 'creates inner joins' do
    join = :join.inner
    join.should be_a Squeel::Nodes::Join
    join._type.should eq Squeel::InnerJoin
  end

  it 'creates outer joins' do
    join = :join.outer
    join.should be_a Squeel::Nodes::Join
    join._type.should eq Squeel::OuterJoin
  end

  it 'creates as nodes' do
    as = :column.as('other_name')
    as.should be_a Squeel::Nodes::As
    as.left.should eq :column
    as.right.should eq 'other_name'
  end

end
