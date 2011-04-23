require 'squeel/constants'
require 'squeel/predicate_methods'

module Squeel
  module Configuration

    # Start a Squeel configuration block
    #
    # Example:
    #
    #   Squeel.configure do |config|
    #     config.load_core_extensions :hash
    #     config.alias_predicate :is_less_than, :lt
    #   end
    def configure
      yield self
    end

    # Load core extensions for Hash, Symbol, or both, via
    # <tt>:hash</tt> and <tt>:symbol</tt> params.
    def load_core_extensions(*exts)
      exts.each do |ext|
        require "core_ext/#{ext}"
      end
    end

    # Create an alias to an existing predication method.
    def alias_predicate(new_name, existing_name)
      raise ArgumentError, 'the existing name should be the base name, not an _any/_all variation' if existing_name.to_s =~ /(_any|_all)$/
      ['', '_any', '_all'].each do |suffix|
        PredicateMethods.class_eval "alias :#{new_name}#{suffix} :#{existing_name}#{suffix} unless defined?(#{new_name}#{suffix})"
      end
    end

  end
end