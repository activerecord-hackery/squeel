require 'spec_helper'

module Squeel
  module Nodes
    describe Stub do
      before do
        @s = Stub.new :attribute
      end

      it 'hashes like a symbol' do
        expect(@s.hash).to eq :attribute.hash
      end

      it 'returns its symbol when sent to_sym' do
        expect(@s.to_sym).to eq :attribute
      end

      it 'returns a string matching its symbol when sent to_s' do
        expect(@s.to_s).to eq 'attribute'
      end

      it 'merges against matching stubs' do
        hash1 = {Stub.new(:attribute) => 1}
        hash2 = {Stub.new(:attribute) => 2}
        merged = hash1.merge(hash2)
        expect(merged.keys.size).to eq(1)
        expect(merged[Stub.new(:attribute)]).to eq 2
      end

      it 'creates a KeyPath when sent an unknown method' do
        keypath = @s.another
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@s, Stub.new(:another)]
      end

      it 'creates a KeyPath when sent #id' do
        keypath = @s.id
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@s, Stub.new(:id)]
      end

      it 'creates a KeyPath when sent #type' do
        keypath = @s.type
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@s, Stub.new(:type)]
      end

      it 'creates a KeyPath with a join endpoint when sent a method with a Class param' do
        keypath = @s.another(Person)
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@s, Join.new(:another, Squeel::InnerJoin, Person)]
      end

      it 'creates a KeyPath with a sifter endpoint when sent #sift' do
        keypath = @s.sift(:blah, 1)
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@s, Sifter.new(:blah, [1])]
      end

      it 'creates an absolute keypath with just an endpoint with ~' do
        node = ~@s
        expect(node).to be_a KeyPath
        expect(node.path).to eq [@s]
      end

      Squeel::Constants::PREDICATES.each do |method_name|
        it "creates #{method_name} predicates with no value" do
          predicate = @s.send(method_name)
          expect(predicate.expr).to eq :attribute
          expect(predicate.method_name).to eq method_name
          expect(predicate.value?).to be false
        end

        it "creates #{method_name} predicates with a value" do
          predicate = @s.send(method_name, 'value')
          expect(predicate.expr).to eq :attribute
          expect(predicate.method_name).to eq method_name
          expect(predicate.value).to eq 'value'
        end
      end

      Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
        aliases.each do |aliaz|
          ['', '_any', '_all'].each do |suffix|
            it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
              predicate = @s.send(aliaz.to_s + suffix)
              expect(predicate.expr).to eq :attribute
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value?).to be false
            end

            it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
              predicate = @s.send((aliaz.to_s + suffix), 'value')
              expect(predicate.expr).to eq :attribute
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value).to eq 'value'
            end
          end
        end
      end

      it 'creates eq predicates with ==' do
        predicate = @s == 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with ^' do
        predicate = @s ^ 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with !=' do
        predicate = @s != 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end if respond_to?('!=')

      it 'creates in predicates with >>' do
        predicate = @s >> [1,2,3]
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates not_in predicates with <<' do
        predicate = @s << [1,2,3]
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :not_in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates matches predicates with =~' do
        predicate = @s =~ '%bob%'
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :matches
        expect(predicate.value).to eq '%bob%'
      end

      it 'creates does_not_match predicates with !~' do
        predicate = @s !~ '%bob%'
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :does_not_match
        expect(predicate.value).to eq '%bob%'
      end if respond_to?('!~')

      it 'creates gt predicates with >' do
        predicate = @s > 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :gt
        expect(predicate.value).to eq 1
      end

      it 'creates gteq predicates with >=' do
        predicate = @s >= 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :gteq
        expect(predicate.value).to eq 1
      end

      it 'creates lt predicates with <' do
        predicate = @s < 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :lt
        expect(predicate.value).to eq 1
      end

      it 'creates lteq predicates with <=' do
        predicate = @s <= 1
        expect(predicate.expr).to eq :attribute
        expect(predicate.method_name).to eq :lteq
        expect(predicate.value).to eq 1
      end

      it 'creates ascending orders' do
        order = @s.asc
        expect(order).to be_ascending
      end

      it 'creates descending orders' do
        order = @s.desc
        expect(order).to be_descending
      end

      it 'creates inner joins' do
        join = @s.inner
        expect(join).to be_a Join
        expect(join._type).to eq Squeel::InnerJoin
      end

      it 'creates outer joins' do
        join = @s.outer
        expect(join).to be_a Join
        expect(join._type).to eq Squeel::OuterJoin
      end

      it 'creates functions with #func' do
        function = @s.func
        expect(function).to be_a Function
      end

      it 'creates as nodes with #as' do
        as = @s.as('other_name')
        expect(as).to be_a Squeel::Nodes::As
        expect(as.left).to eq @s
        expect(as.right).to be_a Arel::Nodes::SqlLiteral
        expect(as.right).to eq 'other_name'
      end

      it 'implements equivalence check' do
        expect([@s, Stub.new(:attribute)].uniq.size).to eq(1)
      end

    end
  end
end
