module Squeel
  module Adapters
    module ActiveRecord
      module BaseExtensions

        def squeel(&block)
          DSL.eval &block
        end

        def sifter(name = nil)
          if Symbol === name && block_given?
            singleton_class.send :define_method, "sifter_#{name}",
                                  lambda {|*args| DSL.exec(*args, &Proc.new)}
          else
            raise ArgumentError, "A name and block are required"
          end
        end

      end
    end
  end
end

ActiveRecord::Base.extend Squeel::Adapters::ActiveRecord::BaseExtensions
