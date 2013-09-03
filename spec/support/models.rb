class Person < ActiveRecord::Base
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
  has_many   :notes, :as => :notable
  has_many :commenters, :through => :comments, :source => :person
  has_many :uniq_commenters, :through => :comments, :source => :person, :uniq => true
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

Dir[File.expand_path('../../blueprints/*.rb', __FILE__)].each do |f|
  require f
end

class Models
  def self.make
    10.times do
      person = Person.make
      2.times do
        UnidentifiedObject.create(:person => person, :name => Sham.object_name)
      end
      Note.make(:notable => person)
      3.times do
        article = Article.make(:person => person)
        3.times do
          article.tags = [Tag.make, Tag.make, Tag.make]
        end
        Note.make(:notable => article)
        10.times do
          Comment.make(:article => article)
        end
      end
      2.times do
        Comment.make(:person => person)
      end
    end

    Comment.make(:body => 'First post!', :article => Article.make(:title => 'Hello, world!'))
    Comment.make(:body => 'Last post!', :article => Article.first, :person => Article.first.commenters.first)
  end
end
