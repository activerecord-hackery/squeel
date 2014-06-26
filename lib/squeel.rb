require 'squeel/configuration'
require 'polyamorous'

module Squeel

  if defined?(Arel::InnerJoin)
    InnerJoin = Arel::InnerJoin
    OuterJoin = Arel::OuterJoin
  else
    InnerJoin = Arel::Nodes::InnerJoin
    OuterJoin = Arel::Nodes::OuterJoin
  end

  extend Configuration

  # Prevent warnings on the console when doing things some might describe as "evil"
  def self.evil_things
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbosity
  end

  def self.deprecate(message)
    external_caller = caller.find {|s| !s.include?('/lib/squeel/')}
    warn "DEPRECATION WARNING: #{message} (called from #{external_caller})"
  end

  # Ruby 1.9 has a zero arity on a Proc with no arity. Prior to that, it mimics
  # Symbol#to_proc and returns -1.
  def self.sane_arity?
    @sane_arity ||= Proc.new {}.arity == 0
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
