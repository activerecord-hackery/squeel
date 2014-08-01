require 'spec_helper'

module Squeel
  module Nodes
    describe Literal do
      subject { Literal.new 'string'}

      it { is_expected.to respond_to :& }
      it { is_expected.to respond_to :| }
      it { is_expected.to respond_to :-@ }

      specify { expect(subject & subject).to be_a And }
      specify { expect(subject | subject).to be_a Or }
      specify { expect(-subject).to be_a Not }

      it 'hashes like its expr' do
        expect(subject.hash).to eq 'string'.hash
      end

      it 'returns nil when sent to_sym' do
        expect(subject.to_sym).to be_nil
      end

      it 'returns a string matching its expr when sent to_s' do
        expect(subject.to_s).to eq 'string'
      end

      Squeel::Constants::PREDICATES.each do |method_name|
        it "creates #{method_name} predicates with no value" do
          predicate = subject.send(method_name)
          expect(predicate.expr).to eq subject
          expect(predicate.method_name).to eq method_name
          expect(predicate.value?).to be false
        end

        it "creates #{method_name} predicates with a value" do
          predicate = subject.send(method_name, 'value')
          expect(predicate.expr).to eq subject
          expect(predicate.method_name).to eq method_name
          expect(predicate.value).to eq 'value'
        end
      end

      Squeel::Constants::PREDICATE_ALIASES.each do |method_name, aliases|
        aliases.each do |aliaz|
          ['', '_any', '_all'].each do |suffix|
            it "creates #{method_name.to_s + suffix} predicates with no value using the alias #{aliaz.to_s + suffix}" do
              predicate = subject.send(aliaz.to_s + suffix)
              expect(predicate.expr).to eq subject
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value?).to be false
            end

            it "creates #{method_name.to_s + suffix} predicates with a value using the alias #{aliaz.to_s + suffix}" do
              predicate = subject.send((aliaz.to_s + suffix), 'value')
              expect(predicate.expr).to eq subject
              expect(predicate.method_name).to eq "#{method_name}#{suffix}".to_sym
              expect(predicate.value).to eq 'value'
            end
          end
        end
      end

      it 'creates eq predicates with ==' do
        predicate = subject == 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with ^' do
        predicate = subject ^ 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end

      it 'creates not_eq predicates with !=' do
        predicate = subject != 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :not_eq
        expect(predicate.value).to eq 1
      end if respond_to?('!=')

      it 'creates in predicates with >>' do
        predicate = subject >> [1,2,3]
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates not_in predicates with <<' do
        predicate = subject << [1,2,3]
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :not_in
        expect(predicate.value).to eq [1,2,3]
      end

      it 'creates matches predicates with =~' do
        predicate = subject =~ '%bob%'
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :matches
        expect(predicate.value).to eq '%bob%'
      end

      it 'creates does_not_match predicates with !~' do
        predicate = subject !~ '%bob%'
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :does_not_match
        expect(predicate.value).to eq '%bob%'
      end if respond_to?('!~')

      it 'creates gt predicates with >' do
        predicate = subject > 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :gt
        expect(predicate.value).to eq 1
      end

      it 'creates gteq predicates with >=' do
        predicate = subject >= 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :gteq
        expect(predicate.value).to eq 1
      end

      it 'creates lt predicates with <' do
        predicate = subject < 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :lt
        expect(predicate.value).to eq 1
      end

      it 'creates lteq predicates with <=' do
        predicate = subject <= 1
        expect(predicate.expr).to eq subject
        expect(predicate.method_name).to eq :lteq
        expect(predicate.value).to eq 1
      end

      it 'creates ascending orders' do
        order = subject.asc
        expect(order).to be_ascending
      end

      it 'creates descending orders' do
        order = subject.desc
        expect(order).to be_descending
      end

      it 'creates as nodes with #as' do
        as = subject.as('other_name')
        expect(as).to be_a Squeel::Nodes::As
        expect(as.left).to eq subject
        expect(as.right).to be_a Arel::Nodes::SqlLiteral
        expect(as.right).to eq 'other_name'
      end

    end
  end
end