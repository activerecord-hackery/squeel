require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe RelationExtensions do

        if ::ActiveRecord::VERSION::STRING >= "4.2"
          include_examples "Relation on ActiveRecord 4.2"
        elsif ::ActiveRecord::VERSION::STRING >= "4.1"
          include_examples "Relation on ActiveRecord 4.1"
        else
          include_examples "Relation on ActiveRecord 3 and 4.0"
        end

      end
    end
  end
end
