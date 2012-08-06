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

  has_many   :outgoing_messages, :class_name => 'Message', :foreign_key => :author_id
  has_many   :incoming_messages, :class_name => 'Message', :foreign_key => :recipient_id

  scope :nil_scope, lambda { nil }

  sifter :name_starts_or_ends_with do |value|
    (name =~ "#{value}%") | (name =~ "%#{value}")
  end
end

class PersonWithNamePrimaryKey < ActiveRecord::Base
  set_primary_key 'name'
  # Set this second, because I'm lazy and don't want to populate another table,
  # and also don't want to clobber the AR connection's primary_key cache.
  set_table_name 'people'
end

class PersonNamedBill < ActiveRecord::Base
  self.table_name = 'people'
  belongs_to :parent, :class_name => 'Person', :foreign_key => :parent_id
  default_scope where{name == 'Bill'}.order{id}
  scope :highly_compensated, where{salary > 200000}
  scope :ending_with_ill, where{name =~ '%ill'}
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
