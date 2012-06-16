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
