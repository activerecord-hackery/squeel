require 'spec_helper'

module Squeel
  module Nodes
    describe Sifter do

      subject { Sifter.new :title_or_body_contains, ['awesome'] }

      specify { subject.name.should eq :title_or_body_contains }
      specify { subject.args.should eq ['awesome'] }

      it { should respond_to :& }
      it { should respond_to :| }
      it { should respond_to :-@ }

      specify { (subject & subject).should be_a And }
      specify { (subject | subject).should be_a Or }
      specify { (-subject).should be_a Not }

    end
  end
end