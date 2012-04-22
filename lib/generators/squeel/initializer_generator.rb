module Squeel
  module Generators
    class InitializerGenerator < ::Rails::Generators::Base

      source_root File.expand_path("../../templates", __FILE__)

      desc 'Creates a sample Squeel initializer.'

      def copy_initializer
        copy_file 'squeel.rb', 'config/initializers/squeel.rb'
      end

    end
  end
end
