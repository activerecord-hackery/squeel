require 'active_record'
require 'squeel'

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => ':memory:'
)

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

        create_table :messages, :force => true do |t|
          t.integer :author_id
          t.integer :recipient_id
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

    def self.make_spec_data
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
end
