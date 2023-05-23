Bundler.setup
require 'searchlogic'
require "pry"
require "pry-stack_explorer"
require "pry-rescue"
require "timecop"

ENV['TZ'] = 'UTC'
Time.zone = 'Eastern Time (US & Canada)'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

if ActiveRecord::VERSION::MAJOR == 3
  ActiveRecord::Base.configurations = true
end

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(:version => 1) do
  create_table :audits do |t|
    t.string :auditable_type
    t.integer :auditable_id
  end

  create_table :companies do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.string :name
    t.string :description
    t.integer :users_count, :default => 0
  end

  create_table :user_groups do |t|
    t.string :name
  end

  create_table :user_groups_users, :id => false do |t|
    t.integer :user_group_id, :null => false
    t.integer :user_id, :null => false
  end

  create_table :users do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.integer :company_id
    t.string :username
    t.string :name
    t.integer :age
    t.boolean :male
    t.string :some_type_id
    t.datetime :whatever_at
  end

  create_table :carts do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.integer :user_id
  end

  create_table :orders do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.integer :user_id
    t.date :shipped_on
    t.float :taxes
    t.float :total
  end

  create_table :fees do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.string :owner_type
    t.integer :owner_id
    t.float :cost
  end

  create_table :line_items do |t|
    t.datetime :created_at
    t.datetime :updated_at
    t.integer :order_id
    t.float :price
  end
end


RSpec.configure do |config|
  config.before(:each) do
    class ::Audit < ActiveRecord::Base
      belongs_to :auditable, :polymorphic => true
    end

    class ::Company < ActiveRecord::Base
      has_many :orders, :through => :users
      has_many :users, :dependent => :destroy
    end

    class ::Cart < ActiveRecord::Base
      belongs_to :user
    end

    class ::UserGroup < ActiveRecord::Base
      has_and_belongs_to_many :users
    end

    class ::User < ActiveRecord::Base
      belongs_to :company, :counter_cache => true
      has_many :carts, :dependent => :destroy
      has_many :orders, :dependent => :destroy

      if ActiveRecord::VERSION::MAJOR == 3
        has_many :orders_big, :class_name => 'Order', :conditions => 'total > 100'
      else
        has_many :orders_big, -> { where('total > 100') }, :class_name => 'Order'
      end

      has_many :audits, :as => :auditable
      has_and_belongs_to_many :user_groups

      self.skip_time_zone_conversion_for_attributes = [:whatever_at]
    end

    class ::Order < ActiveRecord::Base
      belongs_to :user
      has_many :line_items, :dependent => :destroy
    end

    class ::Fee < ActiveRecord::Base
      belongs_to :owner, :polymorphic => true
    end

    class ::LineItem < ActiveRecord::Base
      belongs_to :order
    end

    ::Audit.delete_all
    ::Company.destroy_all
    ::Cart.delete_all
    ::UserGroup.delete_all
    ::User.delete_all
    ::Order.delete_all
    ::Fee.delete_all
    ::LineItem.delete_all
  end

  config.after(:each) do
    ::Object.module_eval do
      remove_const :Audit
      remove_const :Company
      remove_const :Cart
      remove_const :UserGroup
      remove_const :User
      remove_const :Order
      remove_const :Fee
      remove_const :LineItem

      ActiveSupport::Dependencies::Reference.clear!
    end
  end
end

RSpec::Matchers.define :be_similar_sql do |expected|
  match do |actual|
    actual&.gsub(/\s+/, ' ')&.gsub(/\(|\)|"/, '')&.strip ==
      expected&.gsub(/\s+/, ' ')&.gsub(/\(|\)|"/, '')&.strip
  end
end
