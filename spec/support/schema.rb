require 'active_record'
require 'squeel'
require 'pathname'
require 'yaml'

ENV['SQ_DB'] ||= 'sqlite3'

MYSQL_ENV = ENV['SQ_DB'] =~ /mysql/
SQLITE_ENV = ENV['SQ_DB'] == 'sqlite3'
PG_ENV = ENV['SQ_DB'] == 'postgresql'
Q = MYSQL_ENV ? '`' : '"' #Quotes difference in MySQL

module Squeel
  module Test
    extend self

    def config
      @config ||= read_config
    end

    def read_config
      config_file = Pathname.new(ENV['SQ_CONFIG_FILE'] || File.expand_path('../../', __FILE__) + '/config.yml')
      expand_config(YAML.parse(config_file.read).transform)
    end

    def expand_config(config)
      config["databases"].each do |adapter, connection|
        connection['adapter'] ||= adapter
      end

      config
    end

    def build_connection(adapter)
      case adapter
        when 'sqlite3'
          ActiveRecord::Base.establish_connection(
            :adapter  => 'sqlite3',
            :database => ':memory:'
          )
        else
          Squeel::Test.send "rebuild_#{ENV['SQ_DB']}_db"

          ActiveRecord::Base.establish_connection(
            Squeel::Test.config['databases'][ENV['SQ_DB']]
          )
        end
    end

    private
      def rebuild_mysql_db
        config = self.config['databases']['mysql']
        %x( mysqladmin --user=#{config['username']} -f drop #{config['database']} )
        %x( mysql --user=#{config['username']} -e "create DATABASE #{config['database']} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
      end

      def rebuild_mysql2_db
        config = self.config['databases']['mysql2']
        %x( mysqladmin --user=#{config['username']} -f drop #{config['database']} )
        %x( mysql --user=#{config['username']} -e "create DATABASE #{config['database']} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
      end

      def rebuild_postgresql_db
        config = self.config['databases']['postgresql']
        %x( dropdb #{config['database']} )
        %x( createdb -E UTF8 -T template0 #{config['database']} )
    end
  end
end

case ENV['SQ_DB']
  when 'sqlite3', 'mysql', 'mysql2', 'postgresql'
    Squeel::Test.build_connection(ENV['SQ_DB'])
  else
    raise RuntimeError, "Error SQ_DB setting, must be included in sqlite3, mysql, mysql2, postgresql."
  end

silence_stream(STDOUT) do
  ActiveRecord::Migration.verbose = false

  ActiveRecord::Schema.define do
    create_table :depts, :force => true do |t|
      t.string :name
    end

    create_table :people, :force => true do |t|
      t.integer  :parent_id
      t.string   :name
      t.integer  :salary
      t.integer  :dept_id
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

    # Test for polymorphic with source_type
    create_table :users do |t|
      t.string :name
    end

    create_table :memberships do |t|
      t.references :group
      t.integer   :member_id
      t.string    :member_type
      t.boolean   :active
    end

    create_table :packages do |t|
      t.string :name
    end

    create_table :groups do |t|
      t.string :name
    end

    create_table :seats do |t|
      t.string :no
      t.integer :payment_id
    end

    create_table :order_items do |t|
      t.string :orderable_type
      t.integer :orderable_id
      t.integer :quantity
      t.integer :unit_price
    end

    create_table :payments do |t|

    end

  end
end

