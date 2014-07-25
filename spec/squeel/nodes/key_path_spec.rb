require 'spec_helper'

module Squeel
  module Nodes
    describe KeyPath do
      before do
        @k = KeyPath.new([:first, :second])
      end

      it 'appends to its path when endpoint is a Stub' do
        @k.third.fourth.fifth
        expect(@k.path).to eq [:first, :second, :third, :fourth, Stub.new(:fifth)]
      end

      it 'becomes absolute when prefixed with ~' do
        ~@k.third.fourth.fifth
        expect(@k.path).to eq [:first, :second, :third, :fourth, Stub.new(:fifth)]
        expect(@k).to be_absolute
      end

      it 'stops appending once its endpoint is not a Stub' do
        @k.third.fourth.fifth == 'cinco'
        expect(@k.endpoint).to eql Predicate.new(Stub.new(:fifth), :eq, 'cinco')
        expect { @k.another }.to raise_error NoMethodError
      end

      it 'allows specification of a type column' do
        node = @k.type
        expect(node).to be_a KeyPath # not a Class (Ruby 1.8 Object#type)
      end

      it 'sends missing calls to its endpoint if the endpoint responds to them' do
        @k.third.fourth.fifth.matches('Joe%')
        expect(@k.endpoint).to be_a Predicate
        expect(@k.endpoint.expr).to eq :fifth
        expect(@k.endpoint.method_name).to eq :matches
        expect(@k.endpoint.value).to eq 'Joe%'
      end

      it 'creates a polymorphic join at its endpoint' do
        @k.third.fourth.fifth(Person)
        expect(@k.endpoint).to be_a Join
        expect(@k.endpoint).to be_polymorphic
      end

      it 'creates a named function at its endpoint' do
        @k.third.fourth.fifth.max(1,2,3)
        expect(@k.endpoint).to be_a Function
        expect(@k.endpoint.function_name).to eq :max
        expect(@k.endpoint.args).to eq [1,2,3]
      end

      it 'creates as nodes with #as' do
        @k.as('other_name')
        as = @k.endpoint
        expect(as).to be_a Squeel::Nodes::As
        expect(as.left).to eq Stub.new(:fourth)
        expect(as.right).to eq 'other_name'
      end

      it 'creates sifter nodes with #sift' do
        @k.sift(:blah, 1)
        sifter = @k.endpoint
        expect(sifter).to be_a Sifter
      end

      it 'creates AND nodes with & if the endpoint responds to &' do
        node = @k.third.fourth.eq('Bob') & Stub.new(:attr).eq('Joe')
        expect(node).to be_a And
        expect(node.children).to eql [@k, Stub.new(:attr).eq('Joe')]
      end

      it 'raises NoMethodError with & if the endpoint does not respond to &' do
        expect {@k.third.fourth & Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates Or nodes with | if the endpoint responds to |' do
        node = @k.third.fourth.eq('Bob') | Stub.new(:attr).eq('Joe')
        expect(node).to be_a Or
        expect(node.left).to eql @k
        expect(node.right).to eql Stub.new(:attr).eq('Joe')
      end

      it 'raises NoMethodError with | if the endpoint does not respond to |' do
        expect {@k.third.fourth | Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates Operation nodes with - if the endpoint responds to -' do
        node = @k.third.fourth - 4
        expect(node).to be_an Operation
        expect(node.left).to eq @k
        expect(node.right).to eq 4
      end

      it 'raises NoMethodError with - if the endpoint does not respond to -' do
        expect {@k.third.fourth(Person) - Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates NOT nodes with -@ if the endpoint responds to -@' do
        node = - @k.third.fourth.eq('Bob')
        expect(node).to be_a Not
        expect(node.expr).to eql @k
      end

      it 'raises NoMethodError with -@ if the endpoint does not respond to -@' do
        expect {-@k.third.fourth}.to raise_error NoMethodError
      end

      it 'dups its path when it is duped' do
        k1 = KeyPath.new([:one, :two])
        k2 = k1.dup
        k2.three
        expect(k2.path.size).to eq(3)
        expect(k1.path.size).to eq(2)
      end

    end
  end
end
