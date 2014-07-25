require 'spec_helper'

module Squeel
  module Nodes
    describe As do

      subject { As.new 'name', 'alias'}

      it { is_expected.to respond_to :& }
      it { is_expected.to respond_to :| }
      it { is_expected.to respond_to :-@ }

      specify { expect(subject & subject).to be_a And }
      specify { expect(subject | subject).to be_a Or }
      specify { expect(-subject).to be_a Not }
      specify { expect([subject, As.new('name', 'alias')].uniq.size).to eq(1) }

    end
  end
end
