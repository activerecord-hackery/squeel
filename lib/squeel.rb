require 'squeel/configuration'

module Squeel

  extend Configuration

  def self.evil_things
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbosity
  end

  Constants::PREDICATE_ALIASES.each do |original, aliases|
    aliases.each do |aliaz|
      alias_predicate aliaz, original
    end
  end

end

require 'squeel/nodes'
require 'squeel/dsl'
require 'squeel/visitors'
require 'squeel/adapters/active_record'