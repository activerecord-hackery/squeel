require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe BaseExtensions do

        subject { Person }

        it { is_expected.to respond_to :sifter }

        describe '#sifter' do

          subject { Article }

          specify { expect {subject.sifter 'blah'}.to raise_error ArgumentError }

          context 'with a sifter defned via block' do
            before :all do
              subject.sifter :title_or_body_contains do |value|
                (title =~ "%#{value}%") | (body =~ "%#{value}%")
              end
            end

            it { is_expected.to respond_to :sifter_title_or_body_contains }
            specify { expect(subject.sifter_title_or_body_contains('ernie')).to be_a Nodes::Or }
          end

          context 'with a sifter defined via method' do
            before :all do
              def subject.sifter_title_starts_with(val)
                squeel{title =~ "#{val}%"}
              end
            end

            it { is_expected.to respond_to :sifter_title_starts_with }
            specify { expect(subject.sifter_title_starts_with('ernie')).to be_a Nodes::Predicate }
          end

        end

      end
    end
  end
end
