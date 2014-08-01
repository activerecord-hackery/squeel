require 'spec_helper'

module Squeel
  module Nodes
    describe Sifter do

      subject { Sifter.new :title_or_body_contains, ['awesome'] }

      specify { expect(subject.name).to eq :title_or_body_contains }
      specify { expect(subject.args).to eq ['awesome'] }

      it { is_expected.to respond_to :& }
      it { is_expected.to respond_to :| }
      it { is_expected.to respond_to :-@ }

      specify { expect(subject & subject).to be_a And }
      specify { expect(subject | subject).to be_a Or }
      specify { expect(-subject).to be_a Not }
      specify { expect([subject, Sifter.new(:title_or_body_contains, ['awesome'])].uniq.size).to eq(1) }

    end
  end
end
