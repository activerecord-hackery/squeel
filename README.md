# Squeel

Squeel is a rewrite of [MetaWhere](http://metautonomo.us/projects/metawhere).

## Getting started

In your Gemfile:

    gem "squeel"  # Last officially released gem
    # gem "squeel", :git => "git://github.com/ernie/squeel.git" # Track git repo

In an intitializer:

    Squeel.configure do |config|
      # To load hash extensions (to allow for AND (&), OR (|), and NOT (-) against
      # hashes of conditions)
      config.load_core_extensions :hash

      # To load symbol extensions (for a subset of the old MetaWhere functionality,
      # via ARel predicate methods on Symbols: :name.matches, etc)
      # config.load_core_extensions :symbol

      # To load both hash and symbol extensions
      # config.load_core_extensions :hash, :symbol
    end

## The Squeel Query DSL

Squeel enhances the normal ActiveRecord query methods by enabling them to accept
blocks. Inside a block, the Squeel query DSL can be used. Note the use of curly braces
in these examples instead of parentheses. `{}` denotes a Squeel DSL query.

### Stubs

Stubs are, for most intents and purposes, just like Symbols in a normal call to
`Relation#where` (note the need for doubling up on the curly braces here, the first ones
start the block, the second are the hash braces):

    Person.where{{name => 'Ernie'}}
    => SELECT "people".* FROM "people"  WHERE "people"."name" = 'Ernie'

You normally wouldn't bother using the DSL in this case, as a simple hash would
suffice. However, stubs serve as a building block for keypaths, and keypaths are
very handy.

### KeyPaths

A Squeel keypath is essentially a more concise and readable alternative to a
deeply nested hash. For instance, in standard ActiveRecord, you might join several
associations like this to perform a query:

    Person.joins(:articles => {:comments => :person})
    => SELECT "people".* FROM "people"
         INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
         INNER JOIN "comments" ON "comments"."article_id" = "articles"."id"
         INNER JOIN "people" "people_comments" ON "people_comments"."id" = "comments"."person_id"

With a keypath, this would look like:

    Person.joins{articles.comments.person}

A keypath can exist in the context of a hash, and is normally interpreted relative to
the current level of nesting. It can be forced into an "absolute" path by anchoring it with
a ~, like:

    ~articles.comments.person

This isn't quite so useful in the typical hash context, but can be very useful when it comes
to interpreting functions and the like. We'll cover those later.

### Joins

As you saw above, keypaths can be used as shorthand for joins. Additionally, you can
specify join types (or join classes, in the case of polymorphic belongs_to joins):

    Person.joins{articles.outer}
    => SELECT "people".* FROM "people"
       LEFT OUTER JOIN "articles" ON "articles"."person_id" = "people"."id"
    Note.joins{notable(Person).outer}
    => SELECT "notes".* FROM "notes"
       LEFT OUTER JOIN "people"
         ON "people"."id" = "notes"."notable_id"
         AND "notes"."notable_type" = 'Person'

These can also be used inside keypaths:

    Note.joins{notable(Person).articles}
    => SELECT "notes".* FROM "notes"
       INNER JOIN "people" ON "people"."id" = "notes"."notable_id"
         AND "notes"."notable_type" = 'Person'
       INNER JOIN "articles" ON "articles"."person_id" = "people"."id"

### Functions

You can call SQL functions just like you would call a method in Ruby...

    Person.select{coalesce(name, '<no name given>')}
    => SELECT coalesce("people"."name", '<no name given>') FROM "people"

...and you can easily give it an alias:

    person = Person.select{
      coalesce(name, '<no name given>').as(name_with_default)
    }.first
    person.name_with_default # name or <no name given>, depending on data

Symbols 

### SQL Operators

You can use the standard mathematical operators (`+`, `-`, `*`, `/`) inside the Squeel DSL to
specify operators in the resulting SQL, or the `op` method to specify another
custom operator, such as the standard SQL concatenation operator, `||`:

    p = Person.select{name.op('||', '-diddly').as(flanderized_name)}.first
    p.flanderized_name
    => "Aric Smith-diddly" 

As you can see, just like functions, these operations can be given aliases.

### Predicates

All of the ARel "predication" methods can be accessed inside the Squeel DSL, via
their method name, an alias, or an an operator, to create ARel predicates, which are
used in `WHERE` or `HAVING` clauses.

<table>
  <tr>
    <th>SQL</th>
    <th>Predication</th>
    <th>Operator</th>
    <th>Alias</th>
  </tr>
  <tr>
    <td>=</td>
    <td>eq</td>
    <td>==</td>
    <td></td>
  </tr>
  <tr>
    <td>!=</td>
    <td>not_eq</td>
    <td>!=</td>
    <td></td>
  </tr>
  <tr>
    <td>LIKE</td>
    <td>matches</td>
    <td>=~</td>
    <td>like</td>
  </tr>
  <tr>
    <td>NOT LIKE</td>
    <td>does_not_match</td>
    <td>!~</td>
    <td>not_like</td>
  </tr>
  <tr>
    <td>&lt;</td>
    <td>lt</td>
    <td>&lt;</td>
    <td></td>
  </tr>
  <tr>
    <td>&lt;=</td>
    <td>lteq</td>
    <td>&lt;=</td>
    <td>lte</td>
  </tr>
  <tr>
    <td>></td>
    <td>gt</td>
    <td>></td>
    <td></td>
  </tr>
  <tr>
    <td>>=</td>
    <td>gteq</td>
    <td>>=</td>
    <td>gte</td>
  </tr>
  <tr>
    <td>IN</td>
    <td>in</td>
    <td>>></td>
    <td></td>
  </tr>
  <tr>
    <td>NOT IN</td>
    <td>not_in</td>
    <td>&lt;&lt;</td>
    <td></td>
  </tr>
</table>

Let's say we want to generate this simple query:

    SELECT "people".* FROM people WHERE "people"."name" = 'Joe Blow'

All of the following will generate the above SQL:

    Person.where(:name => 'Joe Blow')
    Person.where{{name => 'Joe Blow'}}
    Person.where{{name.eq => 'Joe Blow'}}
    Person.where{name.eq 'Joe Blow'}
    Person.where{name == 'Joe Blow'}
    
Not a very exciting example since equality is handled just fine via the
first example in standard ActiveRecord. But consider the following query:

    SELECT "people".* FROM people
    WHERE ("people"."name" LIKE 'Ernie%' AND "people"."salary" < 50000)
      OR  ("people"."name" LIKE 'Joe%' AND "people"."salary" > 100000)
      
To do this with standard ActiveRecord, we'd do something like:

    Person.where(
      '(name LIKE ? AND salary < ?) OR (name LIKE ? AND salary > ?)',
      'Ernie%', 50000, 'Joe%', 100000
    )
    
With Squeel:

    Person.where{(name =~ 'Ernie%') & (salary < 50000) | (name =~ 'Joe%') & (salary > 100000)}
    
Here, we're using `&` and `|` to generate `AND` and `OR`, respectively.

There are two obvious but important differences between these two code samples, and
both of them have to do with *context*.

1. To read code with SQL interpolation, the structure of the SQL query must
   first be considered, then we must cross-reference the values to be substituted
   with their placeholders. This carries with it a small but perceptible (and
   annoying!) context shift during which we stop thinking about the comparison being
   performed, and instead play "count the arguments", or, in the case of 
   named/hash interpolations, "find the word". The Squeel syntax places
   both sides of each comparison in proximity to one another, allowing us to
   focus on what our code is doing.

2. In the first example, we're starting off with Ruby, switching context to SQL,
   and then back to Ruby, and while we spend time in SQL-land, we're stuck with
   SQL syntax, whether or not it's the best way to express what we're trying to do.
   With Squeel, we're writing Ruby from start to finish. And with Ruby syntax comes
   flexibility to express the query in the way we see fit.

### Predicate aliases

That last bit is important. We can mix and match predicate methods with operators
and take advantage of Ruby's operator precedence or parenthetical grouping to make
our intentions more clear, *on the first read-through*. And if we don't like the
way that the existing predications read, we can create our own aliases in a Squeel
initializer:

    Squeel.configure do |config|
      config.alias_predicate :is_less_than, :lt
    end
    
    Person.where{salary.is_less_than 50000}.to_sql
    # => SELECT "people".* FROM "people"  WHERE "people"."salary" < 50000

And while we're on the topic of helping you make your code more expressive...

### Compound conditions

Let's say you want to check if a Person has a name like one of several possibilities.

    names = ['Ernie%', 'Joe%', 'Mary%']
    Person.where('name LIKE ? OR name LIKE ? OR name LIKE ?', *names)

But you're smart, and you know that you might want to check more or less than
3 names, so you make your query flexible:

    Person.where((['name LIKE ?'] * names.size).join(' OR '), *names)

Yeah... that's readable, all right. How about:

    Person.where{name.like_any names}
    # => SELECT "people".* FROM "people"  
         WHERE (("people"."name" LIKE 'Ernie%' OR "people"."name" LIKE 'Joe%' OR "people"."name" LIKE 'Mary%'))
    
I'm not sure about you, but I much prefer the latter. In short, you can add `_any` or
`_all` to any predicate method, and it would do what you expect, when given an array of
possibilities to compare against.

### Subqueries

You can supply an `ActiveRecord::Relation` as a value for a predicate in order to use
a subquery. So, for example:

    awesome_people = Person.where{awesome == true}
    Article.where{author_id.in(awesome_people.select{id})}
    # => SELECT "articles".* FROM "articles"  
         WHERE "articles"."author_id" IN (SELECT "people"."id" FROM "people"  WHERE "people"."awesome" = 't')

...more docs to come...