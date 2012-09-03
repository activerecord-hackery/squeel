require 'squeel/constants'
require 'squeel/nodes'

module Squeel
  # The Squeel configuration module. The Squeel module extends this to provide its
  # configuration capability.
  module Configuration

    # Start a Squeel configuration block in an initializer.
    #
    # @yield [config] A configuration block
    #
    # @example Load hash and symbol extensions
    #   Squeel.configure do |config|
    #     config.load_core_extensions :hash, :symbol
    #   end
    #
    # @example Alias a predicate
    #   Squeel.configure do |config|
    #     config.alias_ptedicate :is_less_than, :lt
    #   end
    def configure
      yield self
    end

    # Load core extensions for Hash, Symbol, or both
    #
    # @overload load_core_extensions(sym)
    #   Load a single extension
    #   @param [Symbol] sym :hash or :symbol
    # @overload load_core_extensions(sym1, sym2)
    #   Load both extensions
    #   @param [Symbol] sym1 :hash or :symbol
    #   @param [Symbol] sym2 :hash or :symbol
    def load_core_extensions(*exts)
      deprecate 'Core extensions are deprecated and will be removed in Squeel 2.0.'
      exts.each do |ext|
        require "squeel/core_ext/#{ext}"
      end
    end

    # Create an alias to an existing predication method. The _any/_all variations will
    # be created automatically.
    # @param [Symbol] new_name The alias name
    # @param [Symbol] existing_name The existing predicate name
    # @raise [ArgumentError] The existing name is an _any/_all variation, and not the original predicate name
    def alias_predicate(new_name, existing_name)
      raise ArgumentError, 'the existing name should be the base name, not an _any/_all variation' if existing_name.to_s =~ /(_any|_all)$/
      ['', '_any', '_all'].each do |suffix|
        Nodes::PredicateMethods.class_eval "alias :#{new_name}#{suffix} :#{existing_name}#{suffix} unless defined?(#{new_name}#{suffix})"
      end
    end

  end
end
