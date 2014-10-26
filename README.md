# Squeel [![Build Status](https://secure.travis-ci.org/activerecord-hackery/squeel.png)](http://travis-ci.org/activerecord-hackery/squeel) [![endorse](http://api.coderwall.com/ernie/endorsecount.png)](http://coderwall.com/ernie)

Squeel lets you write your Active Record queries with fewer strings, and more Ruby,
by making the Arel awesomeness that lies beneath Active Record more accessible.

Squeel lets you rewrite...

```ruby
Article.where ['created_at >= ?', 2.weeks.ago]
```

...as...

```ruby
Article.where{created_at >= 2.weeks.ago}
```

This is a _good thing_. If you don't agree, Squeel might not be for you. The above is
just a simple example -- Squeel's capable of a whole lot more. Keep reading.

## Getting started

In your Gemfile:

```ruby
gem "squeel"  # Last officially released gem
# gem "squeel", :git => "git://github.com/activerecord-hackery/squeel.git" # Track git repo
```

Then bundle as usual.

If you'd like to customize Squeel's functionality by enabling core
extensions for hashes or symbols, or aliasing some predicates, you can
create a sample initializer with:

```sh
$ rails g squeel:initializer
```

## The Squeel Query DSL

Squeel enhances the normal Active Record query methods by enabling them to accept
blocks. Inside a block, the Squeel query DSL can be used. Note the use of curly braces
in these examples instead of parentheses. `{}` denotes a Squeel DSL query.

Stubs and keypaths are the two primary building blocks used in a Squeel DSL query, so we'll
start by taking a look at them. Most of the other examples that follow will be based on
this "symbol-less" block syntax.

**An important gotcha, before we begin:** The Squeel DSL works its magic using `instance_eval`.
If you've been working with Ruby for a while, you'll know immediately that this means that
_inside_ a Squeel DSL block, `self` isn't the same thing that it is _outside_ the block.

This carries with it an important implication: <strong>Instance variables and instance methods
inside the block won't refer to your object's variables/methods.</strong>

Don't worry, Squeel's got you covered. Use one of the following methods to get access
to your object's methods and variables:

  1. Assign the variable locally before the DSL block, and access it as you would
     normally.
  2. Supply an arity to the DSL block, as in `Person.where{|q| q.name == @my_name}`
     Downside: You'll need to prefix stubs, keypaths, and functions (explained below)
     with the DSL object.
  3. Wrap the method or instance variable inside the block with `my{}`.
     `Person.where{name == my{some_method_to_return_a_name}}`

### Stubs

Stubs are, for most intents and purposes, just like Symbols in a normal call to
`Relation#where` (note the need for doubling up on the curly braces here, the first ones
start the block, the second are the hash braces):

```ruby
Person.where{{name => 'Ernie'}}
# => SELECT "people".* FROM "people"  WHERE "people"."name" = 'Ernie'
```

You normally wouldn't bother using the DSL in this case, as a simple hash would
suffice. However, stubs serve as a building block for keypaths, and keypaths are
very handy.

### KeyPaths

A Squeel keypath is essentially a more concise and readable alternative to a
deeply nested hash. For instance, in standard Active Record, you might join several
associations like this to perform a query:

```ruby
Person.joins(:articles => {:comments => :person})
# => SELECT "people".* FROM "people"
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    INNER JOIN "comments" ON "comments"."article_id" = "articles"."id"
#    INNER JOIN "people" "people_comments" ON "people_comments"."id" = "comments"."person_id"
```

With a keypath, this would look like:

```ruby
Person.joins{articles.comments.person}
```

A keypath can exist in the context of a hash, and is normally interpreted relative to
the current level of nesting. It can be forced into an "absolute" path by anchoring it with
a ~, like:

```ruby
~articles.comments.person
```

This isn't quite so useful in the typical hash context, but can be very useful when it comes
to interpreting functions and the like. We'll cover those later.

### Predicates

All of the Arel "predication" methods can be accessed inside the Squeel DSL, via
their method name, an alias, or an an operator, to create Arel predicates, which are
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
    <td>!= (1.9 only), ^ (1.8)</td>
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
    <td>!~ (1.9 only)</td>
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

```
SELECT "people".* FROM people WHERE "people"."name" = 'Joe Blow'
```

All of the following will generate the above SQL:

```ruby
Person.where(:name => 'Joe Blow')
Person.where{{name => 'Joe Blow'}}
Person.where{{name.eq => 'Joe Blow'}}
Person.where{name.eq 'Joe Blow'}
Person.where{name == 'Joe Blow'}
```

Not a very exciting example since equality is handled just fine via the
first example in standard Active Record. But consider the following query:

```sql
SELECT "people".* FROM people
WHERE ("people"."name" LIKE 'Ernie%' AND "people"."salary" < 50000)
  OR  ("people"."name" LIKE 'Joe%' AND "people"."salary" > 100000)
```

To do this with standard Active Record, we'd do something like:

```ruby
Person.where(
  '(name LIKE ? AND salary < ?) OR (name LIKE ? AND salary > ?)',
  'Ernie%', 50000, 'Joe%', 100000
)
```

With Squeel:

```ruby
Person.where{(name =~ 'Ernie%') & (salary < 50000) | (name =~ 'Joe%') & (salary > 100000)}
```

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
our intentions more clear, on the first read-through. And if we don't like the
way that the existing predications read, we can create our own aliases in a Squeel
configure block:

```ruby
Squeel.configure do |config|
  config.alias_predicate :is_less_than, :lt
end
```
```ruby
Person.where{salary.is_less_than 50000}.to_sql
# => SELECT "people".* FROM "people"  WHERE "people"."salary" < 50000
```

And while we're on the topic of helping you make your code more expressive...

### Compound conditions

Let's say you want to check if a Person has a name like one of several possibilities.

```ruby
names = ['Ernie%', 'Joe%', 'Mary%']
Person.where('name LIKE ? OR name LIKE ? OR name LIKE ?', *names)
```

But you're smart, and you know that you might want to check more or less than
3 names, so you make your query flexible:

```ruby
Person.where((['name LIKE ?'] * names.size).join(' OR '), *names)
```

Yeah... that's readable, all right. How about:

```ruby
Person.where{name.like_any names}
# => SELECT "people".* FROM "people"
#    WHERE (("people"."name" LIKE 'Ernie%' OR "people"."name" LIKE 'Joe%' OR "people"."name" LIKE 'Mary%'))
```

I'm not sure about you, but I much prefer the latter. In short, you can add `_any` or
`_all` to any predicate method, and it would do what you expect, when given an array of
possibilities to compare against.

### Sifters

Sifters are like little snippets of conditions that take parameters. Let's say that you
have a model called Article, and you often want to query for articles that contain a
string in the title or body. So you write a scope:

```ruby
def self.title_or_body_contains(string)
  where{title.matches("%#{string}%") | body.matches("%#{string}%")}
end
```

But then you want to query for people who wrote an article that matches these conditions,
but the scope only works against the model where it was defined. So instead, you write a
sifter:

```ruby
class Article < ActiveRecord::Base
  sifter :title_or_body_contains do |string|
    title.matches("%#{string}%") | body.matches("%#{string}%")
  end
end
```

Now you can write...

```ruby
Article.where{sift :title_or_body_contains, 'awesome'}
# => SELECT "articles".* FROM "articles"
#    WHERE ((
#      "articles"."title" LIKE '%awesome%'
#      OR "articles"."body" LIKE '%awesome%'
#    ))
```

... or ...

```ruby
Person.joins(:articles).
       where{
         {articles => sift(:title_or_body_contains, 'awesome')}
       }
# => SELECT "people".* FROM "people"
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    WHERE ((
#      "articles"."title" LIKE '%awesome%'
#      OR "articles"."body" LIKE '%awesome%'
#    ))
```

Or, you can just modify your previous scope, changing `where` to `squeel`:

```ruby
def self.title_or_body_contains(string)
  squeel{title.matches("%#{string}%") | body.matches("%#{string}%")}
end
```

### Subqueries

You can supply an `ActiveRecord::Relation` as a value for a predicate in order to use
a subquery. So, for example:

```ruby
awesome_people = Person.where{awesome == true}
Article.where{author_id.in(awesome_people.select{id})}
# => SELECT "articles".* FROM "articles"
#    WHERE "articles"."author_id" IN (SELECT "people"."id" FROM "people"  WHERE "people"."awesome" = 't')
```

### Joins

Squeel adds a couple of enhancements to joins. First, keypaths can be used as shorthand for
nested association joins. Second, you can specify join types (inner and outer), and a class
in the case of a polymorphic belongs_to relationship.

```ruby
Person.joins{articles.outer}
# => SELECT "people".* FROM "people"
#    LEFT OUTER JOIN "articles" ON "articles"."person_id" = "people"."id"
Note.joins{notable(Person).outer}
# => SELECT "notes".* FROM "notes"
#    LEFT OUTER JOIN "people"
#      ON "people"."id" = "notes"."notable_id"
#      AND "notes"."notable_type" = 'Person'
```

These can also be used inside keypaths:

```ruby
Note.joins{notable(Person).articles}
# => SELECT "notes".* FROM "notes"
#    INNER JOIN "people" ON "people"."id" = "notes"."notable_id"
#      AND "notes"."notable_type" = 'Person'
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
```

You can refer to these associations when constructing other parts of your query, and
they'll be automatically mapped to the proper table or table alias This is most noticeable
when using self-referential associations:

```ruby
Person.joins{children.parent.children}.
       where{
         (children.name.like 'Ernie%') |
         (children.parent.name.like 'Ernie%') |
         (children.parent.children.name.like 'Ernie%')
       }
# => SELECT "people".* FROM "people"
#    INNER JOIN "people" "children_people" ON "children_people"."parent_id" = "people"."id"
#    INNER JOIN "people" "parents_people" ON "parents_people"."id" = "children_people"."parent_id"
#    INNER JOIN "people" "children_people_2" ON "children_people_2"."parent_id" = "parents_people"."id"
#    WHERE ((("children_people"."name" LIKE 'Ernie%'
#          OR "parents_people"."name" LIKE 'Ernie%')
#          OR "children_people_2"."name" LIKE 'Ernie%'))
```

Keypaths were used here for clarity, but nested hashes would work just as well.

You can also use a subquery in a join.

Notice:
1. Squeel can only accept an ActiveRecord::Relation class of subqueries in a join.
2. Use the chain with caution. You should call `as` first to get a Nodes::As, then call `on` to get a join node.

```ruby
subquery = OrderItem.group(:orderable_id).select { [orderable_id, sum(quantity * unit_price).as(amount)] }
Seat.joins { [payment.outer, subquery.as('seat_order_items').on { id == seat_order_items.orderable_id}.outer] }.
              select { [seat_order_items.amount, "seats.*"] }
# => SELECT "seat_order_items"."amount", seats.*
#    FROM "seats"
#    LEFT OUTER JOIN "payments" ON "payments"."id" = "seats"."payment_id"
#    LEFT OUTER JOIN (
#      SELECT "order_items"."orderable_id",
#             sum("order_items"."quantity" * "order_items"."unit_price") AS amount
#      FROM "order_items"
#      GROUP BY "order_items"."orderable_id"
#    ) seat_order_items ON "seats"."id" = "seat_order_items"."orderable_id"
```

### Includes

Includes works similarly with joins, it uses outer join defaultly. In Rails 4,
you need to use `references` with `includes` together.

#### Rails 4+

```ruby
Person.includes(:articles => {:comments => :person}).references(:all)
# => SELECT "people".* FROM "people"
#    LEFT OUTER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    LEFT OUTER JOIN "comments" ON "comments"."article_id" = "articles"."id"
#    LEFT OUTER JOIN "people" "people_comments" ON "people_comments"."id" = "comments"."person_id"
```

With a keypath, this would look like:

```ruby
Person.includes{articles.comments.person}.references(:all)
```

#### Rails 3.x

```ruby
Person.includes(:articles => {:comments => :person})
# => SELECT "people".* FROM "people"
#    LEFT OUTER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    LEFT OUTER JOIN "comments" ON "comments"."article_id" = "articles"."id"
#    LEFT OUTER JOIN "people" "people_comments" ON "people_comments"."id" = "comments"."person_id"
```

With a keypath, this would look like:

```ruby
Person.includes{articles.comments.person}
```

### Functions

You can call SQL functions just like you would call a method in Ruby...

```ruby
Person.select{coalesce(name, '<no name given>')}
# => SELECT coalesce("people"."name", '<no name given>') FROM "people"
```

...and you can easily give it an alias:

```ruby
person = Person.select{
  coalesce(name, '<no name given>').as(name_with_default)
}.first
person.name_with_default # name or <no name given>, depending on data
```

When you use a stub, symbol, or keypath inside a function call, it'll be interpreted relative to
its place inside any nested associations:

```ruby
Person.joins{articles}.group{articles.title}.having{{articles => {max(id) => id}}}
# => SELECT "people".* FROM "people"
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    GROUP BY "articles"."title"
#    HAVING max("articles"."id") = "articles"."id"
```

If you want to use an attribute from a different branch of the hierarchy, use an absolute
keypath (~) as done here:

```ruby
Person.joins{articles}.group{articles.title}.having{{articles => {max(~id) => id}}}
# => SELECT "people".* FROM "people"
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    GROUP BY "articles"."title"
#    HAVING max("people"."id") = "articles"."id"
```

### SQL Operators

You can use the standard mathematical operators (`+`, `-`, `*`, `/`) inside the Squeel DSL to
specify operators in the resulting SQL, or the `op` method to specify another
custom operator, such as the standard SQL concatenation operator, `||`:

```ruby
p = Person.select{name.op('||', '-diddly').as(flanderized_name)}.first
p.flanderized_name
# => "Aric Smith-diddly"
```

As you can see, just like functions, these operations can be given aliases.

To select more than one attribute (or calculated attribute) simply put them into an array:

```ruby
p = Person.select{[ name.op('||', '-diddly').as(flanderized_name),
                    coalesce(name, '<no name given>').as(name_with_default) ]}.first
p.flanderized_name
# => "Aric Smith-diddly"
p.name_with_default
# => "Aric Smith"
```


## Compatibility with Active Record

Most of the new functionality provided by Squeel is accessed with the new block-style `where{}`
syntax.

All your existing code that uses plain Active Record `where()` queries should continue to work the
same after adding Squeel to your project with one exception: symbols as the value side of a
condition (in normal `where()` clauses).

### Symbols as the value side of a condition (in normal `where()` clauses)

If you have any `where()` clauses that use a symbol as the value side
(right-hand side) of a condition, **you will need to change the symbol into a
string in order for it to continue to be treated as a value**.

Squeel changes the meaning of symbols in the value of a condition to refer to
the name of a **column** instead of simply treating the symbol as a **string literal**.

For example, this query:

```ruby
Person.where(:first_name => :last_name)
```

produces this SQL query in plain Active Record:

```sql
SELECT people.* FROM people WHERE people.first_name = 'last_name'.
```

but produces this SQL query if you are using Squeel:

```sql
SELECT people.* FROM people WHERE people.first_name = people.last_name
```

Note that this new behavior applies to the plain `where()`-style expressions in addition to the new
`where{}` Squeel style.

In order for your existing  `where()` clauses with symbols to continue to behave the same, you
**must** change the symbols into strings. These scopes, for example:

```ruby
scope :active, where(:state => :active)
scope :in_state, lambda {|state| where(:state => state) }
```

should be changed to this:

```ruby
scope :active, where(:state => 'active')
scope :in_state, lambda {|state| where(:state => state.to_s) }
```

For further information, see
[this post to the Rails list](https://groups.google.com/forum/?fromgroups=#!topic/rubyonrails-core/NQJJzZ7R7S0),
[this commit](https://github.com/lifo/docrails/commit/50c5005bafe7e43f81a141cd2c512379aec74325) to
the [Active Record guides](http://edgeguides.rubyonrails.org/active_record_querying.html#hash-conditions),
[#67](https://github.com/activerecord-hackery/squeel/issues/67),
[#75](https://github.com/activerecord-hackery/squeel/issues/75), and
[#171](https://github.com/activerecord-hackery/squeel/issues/171).

## Compatibility with MetaWhere

While the Squeel DSL is the preferred way to access advanced query functionality, you can
still enable methods on symbols to access Arel predications in a similar manner to MetaWhere:

```ruby
Squeel.configure do |config|
  config.load_core_extensions :symbol
end
```
```ruby
Person.joins(:articles => :comments).
       where(:articles => {:comments => {:body.matches => 'Hello!'}})
# => SELECT "people".* FROM "people"
#    INNER JOIN "articles" ON "articles"."person_id" = "people"."id"
#    INNER JOIN "comments" ON "comments"."article_id" = "articles"."id"
#    WHERE "comments"."body" LIKE 'Hello!'
```

This should help to smooth over the transition to the new DSL.

## Contributions

If you'd like to support the continued development of Squeel, please consider
[making a donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=N7QP5N3UB76ME).

To support the project in other ways:

* Use Squeel in your apps, and let me know if you encounter anything that's broken or missing.
  A failing spec is awesome. A pull request is even better!
* Spread the word on Twitter, Facebook, and elsewhere if Squeel's been useful to you. The more
  people who are using the project, the quicker we can find and fix bugs!

## Copyright

Copyright &copy; 2011 [Ernie Miller](http://twitter.com/erniemiller)
