require 'spec_helper'

module Squeel
  module Nodes
    describe As do

      subject { As.new 'name', 'alias'}

      it { should respond_to :& }
      it { should respond_to :| }
      it { should respond_to :-@ }

      specify { (subject & subject).should be_a And }
      specify { (subject | subject).should be_a Or }
      specify { (-subject).should be_a Not }
      specify { [subject, As.new('name', 'alias')].uniq.should have(1).as }

    end
  end
end
