## 1.2.4 (Unreleased)


## 1.2.3 (2015-2-5)
* Support the latest version of Rails 4.2 and 4.1. By @danielrhodes

## 1.2.2 (2014-11-25)

* Size method can return the result correctly when grouping by the column of a
  joined table. Fixes #286
* Properly add 'AND' to generated SQL when joining through a polymorphic model
  with the source type configuration and default scopes above Rails 4. Fixes #270.
* Fix NoMethodError when calling unscope method above Rails 4. By @estum
* Fix error when including HABTM or HMT associations without eager loading.
  Fixes #326.
* Ordering sequence is now correct when chaining multiple order methods. Fixes #276.

## 1.2.1 (2014-07-18)

* Run all specs against sqlite, mysql and postgresql!
* Genereta table names correctly when joining through an association. Fixes#302.
* Enable Arel nodes in Squeel with "|" operator. Fixes #314.
* Properly append binds from a relation used in a subquery. Fixes #272.

## 1.2.0 (2014-07-16)

* Add compatibility to Ruby 2.0+ with Rails 4.1 and 4.2.0.alpha.
  Fixes #301, #305, #307
* Enable using a relation as a subquery. Fixes #309
* Bind params correctly in subquery using associations. Fixes #312
* Use the correct attribute name when finding a Join node. Fixes #273.

## 1.1.1 (2013-09-03)

* Update relation extensions to support new count behavior in Active Record
  4.0.1 (see rails/rails@da9b5d4a)
* Support two-argument version of Relation#from in AR4
* Allow equality/inequality conditions against the name of a belongs_to
  association with an AR::Base value object. Fixes issue #265.

## 1.1.0 (2013-07-14)

* Support for Active Record 4.0.0!
* Deprecated core extensions. In Squeel 2.0, the DSL will be the way to
  construct queries, and Symbol/Hash extensions will go away.
* Prefix generated sifter methods with `sifter_` so as not to interfere with
  similarly-named scopes.
* No longer mutate And nodes when using `&` and `-` on the node

## 1.0.18 (2013-03-07)

* Stop treating nils as quotable. Fixes issue #221.

## 1.0.17 (2013-02-28)

* Revert MySQL hacks, since AR did too.

## 1.0.16 (2013-02-12)

* Port workaround for MySQL's "helpful" casting behavior from Rails 3.2.12

## 1.0.15 (2013-01-23)

* Fix issue #214, don't alter table name when mergine a relation with a default
  scope

## 1.0.14 (2012-12-04 OpenHack Louisville Edition!)

* Use bind values in where_values_hash, to prep for compatibility with 3.2.10
* Allow Symbol#to_proc blocks to fall through to Array's select method

## 1.0.13 (2012-10-11)

* Allow strings in from_value. Fixes incompatibility with acts-as-taggable-on.

## 1.0.12 (2012-10-07)

* Properly uniq order_values before visiting, to fix #163
* Remove an unnecessary passthrough on String in visitor.rb. Fixes #162

## 1.0.11 (2012-09-03)

* Fixed issue #157, resolving problems when joining the same table twice.
* Allow predicates in order/select values
* Support Relation#from in Squeel DSL

## 1.0.10 (2012-09-01)

* Yanked from RubyGems.org due to semantic versioning oversight

## 1.0.9 (2012-08-06)

* Fix issue with duplication of order conditions in default_scope on AR 3.0.x

## 1.0.8 (2012-07-28)

* Fix an issue with properly casting values to column type when used
  on Rails 3.0.x.

## 1.0.7 (2012-07-14)

* Prevent reorder(nil) on reversed SQL from adding an order by id.

## 1.0.6 (2012-06-16)

* Prevent cloned KeyPaths from modifying each other. Fixes #135

## 1.0.5 (2012-06-08)

* Stop visiting group_values on merge. AR hates ARel attributes in
  group_values.

## 1.0.4 (2012-06-07)

* Fix regression in merge causing issues with scopes returning nil

## 1.0.3 (2012-06-07)

* Port fix for Rails CVE-2012-2661 to Squeel.
* Reduce risk of a potential memory leak through overzealous
  calling to to_sym.
* Allow right-hand relation conditions to prevail in Relation#merge.

## 1.0.2 (2012-05-30)

* Add groupings to DSL. Allows control of matched sets of
  parentheses in the absence of not/and/etc. Accessed via
  `_()`.
* Allow As nodes in predicates. This allows casting inside
  a where/having clause with PostgreSQL: `cast(value.as type)`
* Work around issue with Relation#count when where_values
  contains InfixOperations. Fixes #122.

## 1.0.1 (2012-05-02)

* Undefine `type` method on Stubs/KeyPaths for 1.8.x compat.

## 1.0.0 (2012-04-22)

* Official 1.0.0 release.
