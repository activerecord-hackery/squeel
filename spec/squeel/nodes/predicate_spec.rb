require 'spec_helper'

module Squeel
  module Nodes
    describe Predicate do

      context 'ARel predicate methods' do
        before do
          @p = Predicate.new(:attribute)
        end

        Squeel::Constants::PREDICATES.each do |method_name|
          it "creates #{method_name} predicates with no value" do
            predicate = @p.send(method_name)
            predicate.expr.should eq :attribute
            predicate.method_name.should eq method_name
            predicate.value?.should be_false
          end

          it "creates #{method_name} predicates with a value" do
            predicate = @p.send(method_name, 'value')
            predicate.expr.should eq :attribute
            predicate.method_name.should eq method_name
            predicate.value.should eq 'value'
          end
        end

        Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
          aliases.each do |aliaz|
            ['', '_any', '_all'].each do |suffix|
              it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
                predicate = @p.send(aliaz.to_s + suffix)
                predicate.expr.should eq :attribute
                predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
                predicate.value?.should be_false
              end

              it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
                predicate = @p.send((aliaz.to_s + suffix), 'value')
                predicate.expr.should eq :attribute
                predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
                predicate.value.should eq 'value'
              end
            end
          end
        end
      end

      it 'accepts a value on instantiation' do
        @p = Predicate.new :name, :eq, 'value'
        @p.value.should eq 'value'
      end

      it 'sets value via accessor' do
        @p = Predicate.new :name, :eq
        @p.value = 'value'
        @p.value.should eq 'value'
      end

      it 'sets value via %' do
        @p = Predicate.new :name, :eq
        @p % 'value'
        @p.value.should eq 'value'
      end

      it 'can be inquired for value presence' do
        @p = Predicate.new :name, :eq
        @p.value?.should be_false
        @p.value = 'value'
        @p.value?.should be_true
      end

      it 'can be ORed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left | right
        combined.should be_a Nodes::Or
        combined.left.should eq left
        combined.right.should eq right
      end

      it 'can be ANDed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left & right
        combined.should be_a Nodes::And
        combined.children.should eq [left, right]
      end

    end
  end
end