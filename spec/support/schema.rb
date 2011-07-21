require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => ':memory:'
)

class Person < ActiveRecord::Base
  belongs_to :parent, :class_name => 'Person', :foreign_key => :parent_id
  has_many   :children, :class_name => 'Person', :foreign_key => :parent_id
  has_many   :articles
  has_many   :articles_with_condition, :class_name => 'Article', :conditions => {:title => 'Condition'}
  has_many   :comments
  has_many   :condition_article_comments, :through => :articles_with_condition, :source => :comments
  has_many   :authored_article_comments, :through => :articles,
             :source => :comments
  has_many   :notes, :as => :notable
  has_many   :unidentified_objects
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

module Schema
  def self.create
    ActiveRecord::Base.silence do
      ActiveRecord::Migration.verbose = false

      ActiveRecord::Schema.define do
        create_table :people, :force => true do |t|
          t.integer  :parent_id
          t.string   :name
          t.integer  :salary
        end

        create_table :unidentified_objects, :id => false, :force => true do |t|
          t.integer  :person_id
          t.string   :name
        end

        create_table :articles, :force => true do |t|
          t.integer :person_id
          t.string  :title
          t.text    :body
        end

        create_table :comments, :force => true do |t|
          t.integer :article_id
          t.integer :person_id
          t.text    :body
        end

        create_table :tags, :force => true do |t|
          t.string :name
        end

        create_table :articles_tags, :force => true, :id => false do |t|
          t.integer :article_id
          t.integer :tag_id
        end

        create_table :notes, :force => true do |t|
          t.integer :notable_id
          t.string  :notable_type
          t.string  :note
        end

      end
    end

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

  end
end