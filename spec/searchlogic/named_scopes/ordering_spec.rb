require 'spec_helper'

describe Searchlogic::NamedScopes::Ordering do
  it "should have ascending" do
    %w(bjohnson thunt).each { |username| User.create(:username => username) }
    User.ascend_by_username.to_a.should == User.order("username ASC").to_a
  end

  it "should have descending" do
    %w(bjohnson thunt).each { |username| User.create(:username => username) }
    User.descend_by_username.to_a.should == User.order("username DESC").to_a
  end

  it "should have order" do
    User.order('users.username ASC').to_sql.should(be_similar_sql(
      User.ascend_by_username.to_sql))
  end

  it "should have priorty to columns over conflicting association columns" do
    Company.ascend_by_users_count
  end
end
