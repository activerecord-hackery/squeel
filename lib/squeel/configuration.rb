require 'squeel/constants'
require 'squeel/predicate_methods'

module Squeel
  module Configuration

    def configure
      yield self
    end

    def load_core_extensions(*exts)
      exts.each do |ext|
        require "core_ext/#{ext}"
      end
    end

    def alias_predicate(new_name, existing_name)
      raise ArgumentError, 'the existing name should be the base name, not an _any/_all variation' if existing_name.to_s =~ /(_any|_all)$/
      ['', '_any', '_all'].each do |suffix|
        PredicateMethods.class_eval "alias :#{new_name}#{suffix} :#{existing_name}#{suffix} unless defined?(#{new_name}#{suffix})"
      end
    end

  end
end