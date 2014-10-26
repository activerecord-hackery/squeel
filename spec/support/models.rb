class Person < ActiveRecord::Base
  belongs_to :dept
  belongs_to :parent, :class_name => 'Person', :foreign_key => :parent_id
  has_many   :children, :class_name => 'Person', :foreign_key => :parent_id
  has_many   :articles
  has_many   :comments
  if ActiveRecord::VERSION::MAJOR > 3
    has_many   :articles_with_condition, lambda { where :title => 'Condition' },
      :class_name => 'Article'
    has_many   :article_comments_with_first_post,
      lambda { where :body => 'first post' },
      :through => :articles, :source => :comments
  else
    has_many   :articles_with_condition, :conditions => {:title => 'Condition'},
      :class_name => 'Article'
    has_many   :article_comments_with_first_post,
      :conditions => { :body => 'first post' },
      :through => :articles, :source => :comments
  end
  has_many   :condition_article_comments, :through => :articles_with_condition, :source => :comments
  has_many   :authored_article_comments, :through => :articles,
             :source => :comments
  has_many   :notes, :as => :notable
  has_many   :unidentified_objects

  has_many   :outgoing_messages, :class_name => 'Message', :foreign_key => :author_id
  has_many   :incoming_messages, :class_name => 'Message', :foreign_key => :recipient_id

  scope :nil_scope, lambda { nil }
  scope :with_article_title, lambda {|t| joins{articles}.where{articles.title == t}}
  scope :with_article_condition_title, lambda {|t| joins{articles_with_condition}.where{articles_with_condition.title == t}}

  sifter :name_starts_or_ends_with do |value|
    (name =~ "#{value}%") | (name =~ "%#{value}")
  end

  def odd?
    id.odd?
  end
end

class PersonWithNamePrimaryKey < ActiveRecord::Base
  self.primary_key = 'name'
  # Set this second, because I'm lazy and don't want to populate another table,
  # and also don't want to clobber the AR connection's primary_key cache.
  self.table_name = 'people'
end

class PersonNamedBill < ActiveRecord::Base
  self.table_name = 'people'
  belongs_to :parent, :class_name => 'Person', :foreign_key => :parent_id
  if ActiveRecord::VERSION::MAJOR > 3 || ActiveRecord::VERSION::MINOR > 0
    default_scope lambda { where{name == 'Bill'}.order{id} }
  else # 3.0 doesn't support callables for default_scope
    default_scope where{name == 'Bill'}.order{id}
  end
  scope :highly_compensated, lambda { where {salary > 200000} }
  scope :ending_with_ill, lambda { where{name =~ '%ill'} }
  scope :with_salary_equal_to, lambda { |value| where{abs(salary) == value} }
end

class Dept < ActiveRecord::Base
  has_many :people_named_bill_with_low_salary,
    class_name: 'PersonNamedBillAndLowSalary', foreign_key: 'dept_id'
end

class PersonNamedBillAndLowSalary < Person
  if ActiveRecord::VERSION::MAJOR > 3 || ActiveRecord::VERSION::MINOR > 0
    default_scope { where { name == 'Bill' }.where { salary < 20000 } }
  else # 3.0 doesn't support callables for default_scope
    default_scope where { name == 'Bill' }.where { salary < 20000 }
  end
end

class Message < ActiveRecord::Base
  belongs_to :author, :class_name => 'Person'
  belongs_to :recipient, :class_name => 'Person'
end

class UnidentifiedObject < ActiveRecord::Base
  belongs_to :person
end

class Article < ActiveRecord::Base
  belongs_to              :person
  has_many                :comments
  has_and_belongs_to_many :tags
  has_many :notes, :as => :notable
  has_many :commenters, :through => :comments, :source => :person
  if ActiveRecord::VERSION::MAJOR > 3 && ActiveRecord::VERSION::MINOR >= 1
    has_many :uniq_commenters, lambda { uniq }, :through => :comments, :source => :person
  else
    has_many :uniq_commenters, :through => :comments, :source => :person, :uniq => true
  end
end

class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :person
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :articles
end

class Note < ActiveRecord::Base
  belongs_to :notable, :polymorphic => true
end

class User < ActiveRecord::Base
  has_many :memberships, as: :member
  has_many :groups, through: :memberships
  has_many :packages, through: :groups
end

class Package < ActiveRecord::Base
  has_many :memberships, as: :member
end

class Membership < ActiveRecord::Base
  belongs_to :group
  belongs_to :member, polymorphic: true

  if ActiveRecord::VERSION::MAJOR > 3
    default_scope -> { where(active: true) }
  else
    default_scope where(active: true)
  end

  before_save :set_active

  def set_active
    self.active = true
  end
end

class Group < ActiveRecord::Base
  has_many :memberships
  has_many :users, through: :memberships, source: :member, source_type: 'User'
  has_many :packages, through: :memberships, source: :member, source_type: 'Package'
end

class Seat < ActiveRecord::Base
  belongs_to :payment, dependent: :destroy
  has_many(:order_items,
    as: :orderable,
    autosave: true,
    dependent: :destroy
  )
end

class OrderItem < ActiveRecord::Base
  belongs_to :orderable, polymorphic: true
end

class Payment < ActiveRecord::Base
  has_many :seats
end

class Models
  def self.make
    dept = Dept.create(name: Faker::Lorem.name)

    10.times do |i|
      # 10 people total, salary gt 30000
      person = Person.create(name: Faker::Name.name,
        salary: 30000 + (i + 1) * 1000,
        dept: dept)

      2.times do
        # 20 unidentified object total, 2 per person
        person.unidentified_objects.create(name: Faker::Lorem.words(1).first)
      end
      # 10 notes based on people total
      person.notes.create(note: Faker::Lorem.words(7).join(' '))
      3.times do
        # 30 articles total
        article = person.articles.create(title: Faker::Lorem.sentence, body: Faker::Lorem.paragraph)
        3.times do
          # 30 * 3 tags total
          article.tags << Tag.create(name: Faker::Lorem.words(3).join(' '))
        end
        # 30 notes based on articles total
        article.notes.create(note: Faker::Lorem.words(7).join(' '))
        10.times do
          # 30 * 10 comments based on articles total
          article.comments.create(body: Faker::Lorem.paragraph)
        end
      end
      2.times do
        # 20 comments based on people total
        person.comments.create(body: Faker::Lorem.paragraph)
      end
    end

    # an article, a comment based on articles and people
    Article.create(title: 'Hello, world!', body: Faker::Lorem.paragraph).
      comments.create(body: 'First post!', person: Person.last)
    # a comment based on articles and people
    Article.first.comments.create(body: 'Last post!', person: Article.last.commenters.first)

    # So, we created
    # 10 people
    # 31 articles
    # 322 comments(22 p + 302 a, 2 overlaps)
    # 40 notes(10 p + 30 a)
    # 90 tags
    # 20 unidentified objects

    # has many through polymorphic model examples
    users = User.create([{ name: 'batman' }, { name: 'robin' }])
    groups = Group.create([{ name: 'justice league'}, { name: 'batcave stalagmite counting club'}])
    users.first.groups << groups.first
    users.first.groups << groups.last
    users.last.groups << groups.last

    10.times do |i|
      seat = Seat.create(no: i+1)
      seat.order_items.create(unit_price: 10, quantity: 1)

      seat.create_payment if i%2 == 0
    end
  end
end

