require 'spec_helper'

describe Searchlogic::NamedScopes::AssociationConditions do
  it "should create a named scope" do
    Company.users_username_like("bjohnson").to_sql.should(be_similar_sql( 
      Company.joins(:users).merge(User.username_like("bjohnson")).to_sql))
  end

  it "should create a deep named scope" do
    Company.users_orders_total_greater_than(10).to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.joins(:orders).merge(Order.total_greater_than(10))).to_sql))
  end

  it "should allow the use of foreign pre-existing named scopes" do
    User.scope :uname, ->(value) { User.where(username: value) }
    Company.users_uname("bjohnson").to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.uname("bjohnson")).to_sql))
  end

  it "should allow the use of deep foreign pre-existing named scopes" do
    pending
    Order.scope :big_id, -> { User.where("orders.id > 100") }
    Company.users_orders_big_id.to_sql.should(be_similar_sql(
      Company.joins(users: :orders).merge(Order.big_id).to_sql))
  end

  it "should allow the use of foreign pre-existing alias scopes" do
    User.alias_scope :username_has, ->(value) { User.username_like(value) }
    Company.users_username_has("bjohnson").to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.username_has("bjohnson")).to_sql))
  end

  it "should not raise errors for scopes that don't return anything" do
    User.alias_scope :blank_scope, lambda { |value| }
    Company.users_blank_scope("bjohnson").to_sql.should(be_similar_sql(
      Company.joins(:users).to_sql))
  end

  it "should ignore polymorphic associations" do
    lambda { Fee.owner_created_at_gt(Time.now) }.should raise_error(NoMethodError)
  end

  it "should not allow named scopes on non existent association columns" do
    lambda { User.users_whatever_like("bjohnson") }.should raise_error(NoMethodError)
  end

  it "should not allow named scopes on non existent deep association columns" do
    lambda { User.users_orders_whatever_like("bjohnson") }.should raise_error(NoMethodError)
  end

  it "should allow named scopes to be called multiple times and reflect the value passed" do
    Company.users_username_like("bjohnson").to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.username_like("bjohnson")).to_sql))

    Company.users_username_like("thunt").to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.username_like("thunt")).to_sql))
  end

  it "should allow deep named scopes to be called multiple times and reflect the value passed" do
    Company.users_orders_total_greater_than(10).to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.joins(:orders).merge(Order.total_greater_than(10))).to_sql))

    Company.users_orders_total_greater_than(20).to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.joins(:orders).merge(Order.total_greater_than(20))).to_sql))
  end

  it "should have an arity of 1 if the underlying scope has an arity of 1" do
    Company.users_orders_total_greater_than(10)
    Company.searchlogic_scope_arity("users_orders_total_greater_than").should == Order.searchlogic_scope_arity("total_greater_than")
  end

  it "should have an arity of nil if the underlying scope has an arity of nil" do
    Company.users_orders_total_null
    Company.searchlogic_scope_arity("users_orders_total_null").should == Order.searchlogic_scope_arity("total_null")
  end

  it "should have an arity of -1 if the underlying scope has an arity of -1" do
    Company.users_id_equals_any
    Company.searchlogic_scope_arity("users_id_equals_any").should == User.searchlogic_scope_arity("id_equals_any")
  end

  it "should allow aliases" do
    Company.users_username_contains("bjohnson").to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.username_contains("bjohnson")).to_sql))
  end

  it "should allow deep aliases" do
    Company.users_orders_total_gt(10).to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.joins(:orders).merge(Order.total_gt(10))).to_sql))
  end

  it "should include optional associations" do
    pending # this is a problem with using inner joins and left outer joins
    Company.create
    company = Company.create
    user = company.users.create
    order = user.orders.create(:total => 20, :taxes => 3)
    Company.ascend_by_users_orders_total.all.should == Company.all
  end

  it "should implement exclusive scoping" do
    pending # self joins like this confuse the join solver
    scope = Company.users_company_name_like("name").users_company_description_like("description")
    # scope.scope(:find)[:joins].should == [
    #   "INNER JOIN \"users\" ON companies.id = users.company_id",
    #   "INNER JOIN \"companies\" companies_users ON \"companies_users\".id = \"users\".company_id"
    # ]
    lambda { scope.all }.should_not raise_error
  end

  it "should not create the same join twice" do
    scope = Company.users_orders_total_gt(10).users_orders_taxes_lt(5).ascend_by_users_orders_total
    # scope.scope(:find)[:joins].should == [
    #   "INNER JOIN \"users\" ON companies.id = users.company_id",
    #   "INNER JOIN \"orders\" ON orders.user_id = users.id"
    # ]
    lambda { scope.count }.should_not raise_error
  end

  it "should not create the same join twice when traveling through the duplicate join" do
    scope = Company.users_username_like("bjohnson").users_orders_total_gt(100)
    # scope.scope(:find)[:joins].should == [
    #   "INNER JOIN \"users\" ON companies.id = users.company_id",
    #   "INNER JOIN \"orders\" ON orders.user_id = users.id"
    # ]
    lambda { scope.count }.should_not raise_error
  end

  it "should not create the same join twice when traveling through the deep duplicate join" do
    scope = Company.users_orders_total_gt(100).users_orders_line_items_price_gt(20)
    # scope.scope(:find)[:joins].should == [
    #   "INNER JOIN \"users\" ON companies.id = users.company_id",
    #   "INNER JOIN \"orders\" ON orders.user_id = users.id",
    #   "INNER JOIN \"line_items\" ON line_items.order_id = orders.id"
    # ]
    lambda { scope.all }.should_not raise_error
  end

  it "should allow the use of :include when a join was created" do
    company = Company.create
    user = company.users.create
    order = user.orders.create(:total => 20, :taxes => 3)
    Company.users_orders_total_gt(10).users_orders_taxes_lt(5).ascend_by_users_orders_total.includes(:users).to_a.should == Company.all.to_a
  end

  it "should allow the use of deep :include when a join was created" do
    company = Company.create
    user = company.users.create
    order = user.orders.create(:total => 20, :taxes => 3)
    Company.users_orders_total_gt(10).users_orders_taxes_lt(5).ascend_by_users_orders_total.includes(:users => :orders).to_a.should == Company.all.to_a
  end

  it "should allow the use of :include when traveling through the duplicate join" do
    company = Company.create
    user = company.users.create(:username => "bjohnson")
    order = user.orders.create(:total => 20, :taxes => 3)
    Company.users_username_like("bjohnson").users_orders_taxes_lt(5).ascend_by_users_orders_total.includes(:users).to_a.should == Company.all.to_a
  end

  it "should allow the use of deep :include when traveling through the duplicate join" do
    company = Company.create
    user = company.users.create(:username => "bjohnson")
    order = user.orders.create(:total => 20, :taxes => 3)
    Company.users_orders_taxes_lt(50).ascend_by_users_orders_total.includes(:users => :orders).to_a.should == Company.all.to_a
  end

  it "should automatically add string joins if the association condition is using strings" do
    string_joins = [
      " INNER JOIN \"users\" ON users.company_id = companies.id ",
      " INNER JOIN \"orders\" ON orders.user_id = users.id "
    ]

    User.scope(:orders_big_id, -> { User.joins(string_joins) })
    Company.users_orders_big_id.to_sql.should(be_similar_sql(
      Company.joins(:users).merge(User.joins(string_joins)).to_sql))
  end

  it "should order the join statements ascending by the fieldnames so that we don't get double joins where the only difference is that the order of the fields is different" do
    company = Company.create
    user = company.users.create(:company_id => company.id)
    company.users.company_id_eq(company.id).should == [user]
  end

  it "should sanitize the scope on a foreign model instead of passing the raw options back to the original" do
    Company.scope :users_count_10, -> { Company.where(users_count: 10) }
    User.company_users_count_10.to_sql.should(be_similar_sql(
      User.joins(:company).merge(Company.where(users_count: 10)).to_sql))
  end

  it "should delegate to polymorphic relationships" do
    Audit.auditable_user_type_name_like("ben").to_sql.should(be_similar_sql( 
      Audit.joins(Audit.inner_polymorphic_join(:user, as: :auditable)).merge(User.name_like("ben")).to_sql))
  end

  it "should delegate to polymorphic relationships (with a lazy split on _type_)" do
    Audit.auditable_user_type_some_type_id_like("ben").to_sql.should(be_similar_sql( 
    Audit.joins(Audit.inner_polymorphic_join(:user, as: :auditable)).merge(User.some_type_id_like("ben")).to_sql))
  end

  it "should allow any on a has_many relationship" do
    company1 = Company.create
    user1 = company1.users.create
    company2 = Company.create
    user2 = company2.users.create
    user3 = company2.users.create

    Company.users_id_equals_any([user2.id, user3.id]).all.uniq.should == [company2]
  end

  it "should allow dynamic scope generation on associations without losing association scope options" do
    user = User.create
    Order.create :user => user, :shipped_on => Time.now
    Order.create :shipped_on => Time.now
    Order.scope :shipped_on_not_null, -> { Order.where('shipped_on is not null') }
    user.orders.count.should == 1
    user.orders.shipped_on_not_null.shipped_on_greater_than(2.days.ago).count.should == 1
  end

  it "should allow chained dynamic scopes without losing association scope conditions" do
    user = User.create
    order1 = Order.create :user => user, :shipped_on => Time.now, :total => 2
    order2 = Order.create :shipped_on => Time.now, :total => 2
    user.orders.id_equals(order1.id).count.should == 1
    user.orders.id_equals(order1.id).total_equals(2).count.should == 1
  end

  it "shouldn't cache the lambda of a named_scope for a chained association" do
    user = User.create
    Order.create :user => user, :shipped_on => Time.current

    # create the scope and use it through a chained association
    Order.scope :shipped, lambda { Order.where("shipped_on <= ?", Time.current) }
    User.orders_shipped

    # simulate a day passing after the chained scope is first used
    Timecop.travel(Date.tomorrow)

    # make a new object that is active on our simulated day
    Order.create :user => user, :shipped_on => Time.current

    # we have 2 orders and both were shipped on or before the current time,
    # so both should be included in the scope
    user.orders.count.should == 2
    User.orders_shipped.count.should == 2
  end

  it "should allow Marshal.dump on objects that only have polymorphic associations where a polymorphic association is loaded" do
    audit = Audit.create
    audit.auditable = User.create
    lambda { Marshal.dump(audit) }.should_not raise_error
  end
end
