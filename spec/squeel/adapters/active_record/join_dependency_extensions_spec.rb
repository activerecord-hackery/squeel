require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe JoinDependencyExtensions do
        before do
          @jd = new_join_dependency(Person, {}, [])
        end

        if ::ActiveRecord::VERSION::STRING >= "4.2"
          include_examples "Join Dependency on ActiveRecord 4.2"
        elsif ::ActiveRecord::VERSION::STRING >= "4.1"
          include_examples "Join Dependency on ActiveRecord 4.1"
        else
          include_examples "Join Dependency on ActiveRecord 3 and 4.0"
        end

      end
    end
  end
end
