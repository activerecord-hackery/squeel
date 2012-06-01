## 1.0.3 (unreleased)

* Port fix for Rails CVE-2012-2661 to Squeel.
* Reduce risk of a potential memory leak through overzealous
  calling to to_sym.

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
