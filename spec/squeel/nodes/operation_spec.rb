require 'spec_helper'

module Squeel
  module Nodes
    describe Operation do
      before do
        @o = dsl{name + 1}
      end

      Squeel::Constants::PREDICATES.each do |method_name|
        it "creates #{method_name} predicates with no value" do
          predicate = @o.send(method_name)
          expect(predicate.expr).to eq @o
          expect(predicate.method_name).to eq method_name
          expect(predicate.value?).to be false
        end

        it "creates #{method_name} predicates with a value" do
          predicate = @o.send(method_name, 'value')
          expect(predicate.expr).to eq @o
          expect(predicate.method_name).to eq method_name
          expect(predicate.value).to eq 'value'
        end
      end

      Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
        aliases.each do |aliaz|
          ['', '_any', '_all'].each do |suffix|
            it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
              predicate = @o.send(aliaz.to_s + suffix)
              expect(predicate.expr).to eq @o
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value?).to be false
            end

            it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
              predicate = @o.send((aliaz.to_s + suffix), 'value')
              expect(predicate.expr).to eq @o
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value).to eq 'value'
            end
          end
        end
      end

      it 'creates ascending Order nodes with #asc' do
        order = @o.asc
        expect(order.expr).to eq @o
        expect(order).to be_ascending
      end

      it 'creates descending Order nodes with #desc' do
        order = @o.desc
        expect(order.expr).to eq @o
        expect(order).to be_descending
      end

      it 'creates eq predicates with ==' do
        predicate = @o == 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with ^' do
        predicate = @o ^ 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with !=' do
        predicate = @o != 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end if respond_to?('!=')

      it 'creates in predicates with >>' do
        predicate = @o >> [1,2,3]
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates not_in predicates with <<' do
        predicate = @o << [1,2,3]
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :not_in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates matches predicates with =~' do
        predicate = @o =~ '%bob%'
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :matches
        expect(predicate.value).to eq '%bob%'
      end

      it 'creates does_not_match predicates with !~' do
        predicate = @o !~ '%bob%'
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :does_not_match
        expect(predicate.value).to eq '%bob%'
      end if respond_to?('!~')

      it 'creates gt predicates with >' do
        predicate = @o > 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :gt
        expect(predicate.value).to eq 1
      end

      it 'creates gteq predicates with >=' do
        predicate = @o >= 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :gteq
        expect(predicate.value).to eq 1
      end

      it 'creates lt predicates with <' do
        predicate = @o < 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :lt
        expect(predicate.value).to eq 1
      end

      it 'creates lteq predicates with <=' do
        predicate = @o <= 1
        expect(predicate.expr).to eq @o
        expect(predicate.method_name).to eq :lteq
        expect(predicate.value).to eq 1
      end

      it 'can be ORed with another node' do
        right = Predicate.new :name, :eq, 'Bob'
        combined = @o | right
        expect(combined).to be_a Nodes::Or
        expect(combined.left).to eq @o
        expect(combined.right).to eq right
      end

      it 'can be ANDed with another node' do
        right = Predicate.new :name, :eq, 'Bob'
        combined = @o & right
        expect(combined).to be_a Nodes::And
        expect(combined.children).to eq [@o, right]
      end

      it 'can be negated' do
        negated = -@o
        expect(negated).to be_a Nodes::Not
        expect(negated.expr).to eq @o
      end

      it 'implements equivalence check' do
        other = dsl{name + 1}
        array = [@o, other]
        expect(array.uniq.size).to eq(1)
      end

    end
  end
end
