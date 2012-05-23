require 'squeel/configuration'

module Squeel

  extend Configuration

  # Prevent warnings on the console when doing things some might describe as "evil"
  def self.evil_things
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbosity
  end

  # Set up initial predicate aliases
  Constants::PREDICATE_ALIASES.each do |original, aliases|
    aliases.each do |aliaz|
      alias_predicate aliaz, original
    end
  end

end

require 'squeel/dsl'
require 'squeel/visitors'
require 'squeel/adapters/active_record'
