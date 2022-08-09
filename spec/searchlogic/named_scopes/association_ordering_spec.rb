require 'spec_helper'

describe Searchlogic::NamedScopes::Ordering do
  it "should allow ascending" do
    Company.ascend_by_users_username.to_sql.should ==
      Company.joins(:users).merge(User.ascend_by_username).to_sql
  end

  it "should allow descending" do
    Company.descend_by_users_username.to_sql.should ==
      Company.joins(:users).merge(User.descend_by_username).to_sql
  end

  it "should allow deep ascending" do
    Company.ascend_by_users_orders_total.to_sql.should ==
      Company.joins(:users).merge(User.joins(:orders).merge(Order.ascend_by_total)).to_sql
  end

  it "should allow deep descending" do
    Company.descend_by_users_orders_total.to_sql.should ==
      Company.joins(:users).merge(User.joins(:orders).merge(Order.descend_by_total)).to_sql
  end

  it "should ascend with a belongs to" do
    User.ascend_by_company_name.to_sql.should ==
      User.joins(:company).merge(Company.ascend_by_name).to_sql
  end

  it "should ascend with a polymorphic belongs to" do
    Audit.descend_by_auditable_user_type_username.to_sql.should ==
      Audit.joins(Audit.inner_polymorphic_join(:user, as: :auditable)).merge(User.descend_by_username).to_sql
  end
end
