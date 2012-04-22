Squeel.configure do |config|
  # To load hash extensions (to allow for AND (&), OR (|), and NOT (-) against
  # hashes of conditions):
  #
  # config.load_core_extensions :hash

  # To load symbol extensions (for a subset of the old MetaWhere functionality,
  # via ARel predicate methods on Symbols: :name.matches, etc):
  #
  # NOTE: Not recommended. Learn the new DSL. Use it. Love it.
  #
  # config.load_core_extensions :symbol

  # To load both hash and symbol extensions:
  #
  # config.load_core_extensions :hash, :symbol

  # Alias an existing predicate to a new name. Use the non-grouped
  # name -- the any/all variants will also be created. For example,
  # to alias the standard "lt" predicate to "less_than", and gain
  # "less_than_any" and "less_than_all" as well:
  #
  # config.alias_predicate :less_than, :lt
end
