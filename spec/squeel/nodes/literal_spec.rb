require 'spec_helper'

module Squeel
  module Nodes
    describe Literal do
      before do
        @l = Literal.new 'string'
      end

      it 'hashes like its expr' do
        @l.hash.should eq 'string'.hash
      end

      it 'returns nil when sent to_sym' do
        @l.to_sym.should be_nil
      end

      it 'returns a string matching its expr when sent to_s' do
        @l.to_s.should eq 'string'
      end

      Squeel::Constants::PREDICATES.each do |method_name|
        it "creates #{method_name} predicates with no value" do
          predicate = @l.send(method_name)
          predicate.expr.should eq @l
          predicate.method_name.should eq method_name
          predicate.value?.should be_false
        end

        it "creates #{method_name} predicates with a value" do
          predicate = @l.send(method_name, 'value')
          predicate.expr.should eq @l
          predicate.method_name.should eq method_name
          predicate.value.should eq 'value'
        end
      end

      Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
        aliases.each do |aliaz|
          ['', '_any', '_all'].each do |suffix|
            it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
              predicate = @l.send(aliaz.to_s + suffix)
              predicate.expr.should eq @l
              predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
              predicate.value?.should be_false
            end

            it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
              predicate = @l.send((aliaz.to_s + suffix), 'value')
              predicate.expr.should eq @l
              predicate.method_name.should eq "#{method_name}#{suffix}".to_sym
              predicate.value.should eq 'value'
            end
          end
        end
      end

      it 'creates eq predicates with ==' do
        predicate = @l == 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :eq
        predicate.value.should eq 1
      end

      it 'creates not_eq predicates with ^' do
        predicate = @l ^ 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :not_eq
        predicate.value.should eq 1
      end

      it 'creates not_eq predicates with !=' do
        predicate = @l != 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :not_eq
        predicate.value.should eq 1
      end if respond_to?('!=')

      it 'creates in predicates with >>' do
        predicate = @l >> [1,2,3]
        predicate.expr.should eq @l
        predicate.method_name.should eq :in
        predicate.value.should eq [1,2,3]
      end

      it 'creates not_in predicates with <<' do
        predicate = @l << [1,2,3]
        predicate.expr.should eq @l
        predicate.method_name.should eq :not_in
        predicate.value.should eq [1,2,3]
      end

      it 'creates matches predicates with =~' do
        predicate = @l =~ '%bob%'
        predicate.expr.should eq @l
        predicate.method_name.should eq :matches
        predicate.value.should eq '%bob%'
      end

      it 'creates does_not_match predicates with !~' do
        predicate = @l !~ '%bob%'
        predicate.expr.should eq @l
        predicate.method_name.should eq :does_not_match
        predicate.value.should eq '%bob%'
      end if respond_to?('!~')

      it 'creates gt predicates with >' do
        predicate = @l > 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :gt
        predicate.value.should eq 1
      end

      it 'creates gteq predicates with >=' do
        predicate = @l >= 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :gteq
        predicate.value.should eq 1
      end

      it 'creates lt predicates with <' do
        predicate = @l < 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :lt
        predicate.value.should eq 1
      end

      it 'creates lteq predicates with <=' do
        predicate = @l <= 1
        predicate.expr.should eq @l
        predicate.method_name.should eq :lteq
        predicate.value.should eq 1
      end

      it 'creates ascending orders' do
        order = @l.asc
        order.should be_ascending
      end

      it 'creates descending orders' do
        order = @l.desc
        order.should be_descending
      end

      it 'creates as nodes with #as' do
        as = @l.as('other_name')
        as.should be_a Squeel::Nodes::As
        as.left.should eq @l
        as.right.should be_a Arel::Nodes::SqlLiteral
        as.right.should eq 'other_name'
      end

    end
  end
end