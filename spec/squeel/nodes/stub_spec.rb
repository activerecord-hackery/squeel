require 'spec_helper'

module Squeel
  module Nodes
    describe Stub do
      before do
        @s = Stub.new :attribute
      end

      it 'hashes like a symbol' do
        @s.hash.should eq :attribute.hash
      end

      it 'returns its symbol when sent to_sym' do
        @s.to_sym.should eq :attribute
      end

      it 'returns a string matching its symbol when sent to_s' do
        @s.to_s.should eq 'attribute'
      end

      it 'merges against matching stubs' do
        hash1 = {Stub.new(:attribute) => 1}
        hash2 = {Stub.new(:attribute) => 2}
        merged = hash1.merge(hash2)
        merged.keys.should have(1).key
        merged[Stub.new(:attribute)].should eq 2
      end

      it 'creates a KeyPath when sent an unknown method' do
        keypath = @s.another
        keypath.should be_a KeyPath
        keypath.path.should eq [@s, Stub.new(:another)]
      end

      it 'creates a KeyPath when sent #id' do
        keypath = @s.id
        keypath.should be_a KeyPath
        keypath.path.should eq [@s, Stub.new(:id)]
      end

      it 'creates a KeyPath when sent #type' do
        keypath = @s.type
        keypath.should be_a KeyPath
        keypath.path.should eq [@s, Stub.new(:type)]
      end

      it 'creates a KeyPath with a join endpoint when sent a method with a Class param' do
        keypath = @s.another(Person)
        keypath.should be_a KeyPath
        keypath.path.should eq [@s, Join.new(:another, Squeel::InnerJoin, Person)]
      end

      it 'creates a KeyPath with a sifter endpoint when sent #sift' do
        keypath = @s.sift(:blah, 1)
        keypath.should be_a KeyPath
        keypath.path.should eq [@s, Sifter.new(:blah, [1])]
      end

      it 'creates an absolute keypath with just an endpoint with ~' do
        node = ~@s
        node.should be_a KeyPath
        node.path.should eq [@s]
      end

      Squeel::Constants::PREDICATES.each do |method_name|
        it "creates #{method_name} predicates with no value" do
          predicate = @s.send(method_name)
          predicate.expr.should eq :attribute
          predicate.method_name.should eq method_name
          predicate.value?.should be_false
        end

        it "creates #{method_name} predicates with a value" do
          predicate = @s.send(method_name, 'value')
          predicate.expr.should eq :attribute
          predicate.method_name.should eq method_name
          predicate.value.should eq 'value'
        end
      end

      Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
        aliases.each do |aliaz|
          ['', '_any', '_all'].each do |suffix|
            it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
              predicate = @s.send(aliaz.to_s + suffix)
              predicate.expr.should eq :attribute
              predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
              predicate.value?.should be_false
            end

            it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
              predicate = @s.send((aliaz.to_s + suffix), 'value')
              predicate.expr.should eq :attribute
              predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
              predicate.value.should eq 'value'
            end
          end
        end
      end

      it 'creates eq predicates with ==' do
        predicate = @s == 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :eq
        predicate.value.should eq 1
      end

      it 'creates not_eq predicates with ^' do
        predicate = @s ^ 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :not_eq
        predicate.value.should eq 1
      end

      it 'creates not_eq predicates with !=' do
        predicate = @s != 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :not_eq
        predicate.value.should eq 1
      end if respond_to?('!=')

      it 'creates in predicates with >>' do
        predicate = @s >> [1,2,3]
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :in
        predicate.value.should eq [1,2,3]
      end

      it 'creates not_in predicates with <<' do
        predicate = @s << [1,2,3]
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :not_in
        predicate.value.should eq [1,2,3]
      end

      it 'creates matches predicates with =~' do
        predicate = @s =~ '%bob%'
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :matches
        predicate.value.should eq '%bob%'
      end

      it 'creates does_not_match predicates with !~' do
        predicate = @s !~ '%bob%'
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :does_not_match
        predicate.value.should eq '%bob%'
      end if respond_to?('!~')

      it 'creates gt predicates with >' do
        predicate = @s > 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :gt
        predicate.value.should eq 1
      end

      it 'creates gteq predicates with >=' do
        predicate = @s >= 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :gteq
        predicate.value.should eq 1
      end

      it 'creates lt predicates with <' do
        predicate = @s < 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :lt
        predicate.value.should eq 1
      end

      it 'creates lteq predicates with <=' do
        predicate = @s <= 1
        predicate.expr.should eq :attribute
        predicate.method_name.should eq :lteq
        predicate.value.should eq 1
      end

      it 'creates ascending orders' do
        order = @s.asc
        order.should be_ascending
      end

      it 'creates descending orders' do
        order = @s.desc
        order.should be_descending
      end

      it 'creates inner joins' do
        join = @s.inner
        join.should be_a Join
        join._type.should eq Squeel::InnerJoin
      end

      it 'creates outer joins' do
        join = @s.outer
        join.should be_a Join
        join._type.should eq Squeel::OuterJoin
      end

      it 'creates functions with #func' do
        function = @s.func
        function.should be_a Function
      end

      it 'creates as nodes with #as' do
        as = @s.as('other_name')
        as.should be_a Squeel::Nodes::As
        as.left.should eq @s
        as.right.should be_a Arel::Nodes::SqlLiteral
        as.right.should eq 'other_name'
      end

      it 'implements equivalence check' do
        [@s, Stub.new(:attribute)].uniq.should have(1).element
      end

    end
  end
end
