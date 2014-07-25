require 'spec_helper'

describe Symbol do

  Squeel::Constants::PREDICATES.each do |method_name|
    it "creates #{method_name} predicates with no value" do
      predicate = :attribute.send(method_name)
      expect(predicate.expr).to eq :attribute
      expect(predicate.method_name).to eq method_name
      expect(predicate.value?).to be false
    end

    it "creates #{method_name} predicates with a value" do
      predicate = :attribute.send(method_name, 'value')
      expect(predicate.expr).to eq :attribute
      expect(predicate.method_name).to eq method_name
      expect(predicate.value).to eq 'value'
    end
  end

  Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
    aliases.each do |aliaz|
      ['', '_any', '_all'].each do |suffix|
        it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
          predicate = :attribute.send(aliaz.to_s + suffix)
          expect(predicate.expr).to eq :attribute
          expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
          expect(predicate.value?).to be false
        end

        it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
          predicate = :attribute.send((aliaz.to_s + suffix), 'value')
          expect(predicate.expr).to eq :attribute
          expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
          expect(predicate.value).to eq 'value'
        end
      end
    end
  end

  it 'creates ascending orders' do
    order = :attribute.asc
    expect(order).to be_ascending
  end

  it 'creates descending orders' do
    order = :attribute.desc
    expect(order).to be_descending
  end

  it 'creates functions' do
    function = :function.func
    expect(function).to be_a Squeel::Nodes::Function
  end

  it 'creates inner joins' do
    join = :join.inner
    expect(join).to be_a Squeel::Nodes::Join
    expect(join._type).to eq Squeel::InnerJoin
  end

  it 'creates outer joins' do
    join = :join.outer
    expect(join).to be_a Squeel::Nodes::Join
    expect(join._type).to eq Squeel::OuterJoin
  end

  it 'creates as nodes' do
    as = :column.as('other_name')
    expect(as).to be_a Squeel::Nodes::As
    expect(as.left).to eq :column
    expect(as.right).to eq 'other_name'
  end

end
