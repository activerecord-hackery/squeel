require 'spec_helper'

module Squeel
  module Nodes
    describe KeyPath do
      before do
        @k = KeyPath.new(:first, :second)
      end

      it 'appends to its path when endpoint is a Stub' do
        @k.third.fourth.fifth
        @k.path.should eq [:first, :second, :third, :fourth]
        @k.endpoint.should eq Stub.new(:fifth)
      end

      it 'becomes absolute when prefixed with ~' do
        ~@k.third.fourth.fifth
        @k.path.should eq [:first, :second, :third, :fourth]
        @k.endpoint.should eq Stub.new(:fifth)
        @k.should be_absolute
      end

      it 'stops appending once its endpoint is not a Stub' do
        @k.third.fourth.fifth == 'cinco'
        @k.endpoint.should eq Predicate.new(Stub.new(:fifth), :eq, 'cinco')
        expect { @k.another }.to raise_error NoMethodError
      end

      it 'sends missing calls to its endpoint if the endpoint responds to them' do
        @k.third.fourth.fifth.matches('Joe%')
        @k.endpoint.should be_a Predicate
        @k.endpoint.expr.should eq :fifth
        @k.endpoint.method_name.should eq :matches
        @k.endpoint.value.should eq 'Joe%'
      end

      it 'creates a polymorphic join at its endpoint' do
        @k.third.fourth.fifth(Person)
        @k.endpoint.should be_a Join
        @k.endpoint.should be_polymorphic
      end

      it 'creates a named function at its endpoint' do
        @k.third.fourth.fifth.max(1,2,3)
        @k.endpoint.should be_a Function
        @k.endpoint.name.should eq :max
        @k.endpoint.args.should eq [1,2,3]
      end

      it 'creates as nodes with #as' do
        @k.as('other_name')
        as = @k.endpoint
        as.should be_a Squeel::Nodes::As
        as.left.should eq Stub.new(:fourth)
        as.right.should eq 'other_name'
      end

      it 'creates sifter nodes with #sift' do
        @k.sift(:blah, 1)
        sifter = @k.endpoint
        sifter.should be_a Sifter
      end

      it 'creates AND nodes with & if the endpoint responds to &' do
        node = @k.third.fourth.eq('Bob') & Stub.new(:attr).eq('Joe')
        node.should be_a And
        node.children.should eq [@k, Stub.new(:attr).eq('Joe')]
      end

      it 'raises NoMethodError with & if the endpoint does not respond to &' do
        expect {@k.third.fourth & Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates Or nodes with | if the endpoint responds to |' do
        node = @k.third.fourth.eq('Bob') | Stub.new(:attr).eq('Joe')
        node.should be_a Or
        node.left.should eq @k
        node.right.should eq Stub.new(:attr).eq('Joe')
      end

      it 'raises NoMethodError with | if the endpoint does not respond to |' do
        expect {@k.third.fourth | Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates Operation nodes with - if the endpoint responds to -' do
        node = @k.third.fourth - 4
        node.should be_an Operation
        node.left.should eq @k
        node.right.should eq 4
      end

      it 'raises NoMethodError with - if the endpoint does not respond to -' do
        expect {@k.third.fourth(Person) - Stub.new(:attr).eq('Joe')}.to raise_error NoMethodError
      end

      it 'creates NOT nodes with -@ if the endpoint responds to -@' do
        node = - @k.third.fourth.eq('Bob')
        node.should be_a Not
        node.expr.should eq @k
      end

      it 'raises NoMethodError with -@ if the endpoint does not respond to -@' do
        expect {-@k.third.fourth}.to raise_error NoMethodError
      end

    end
  end
end