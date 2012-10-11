module Squeel
  module Visitors
    class FromVisitor < Visitor

      alias :visit_String :visit_passthrough

    end
  end
end
