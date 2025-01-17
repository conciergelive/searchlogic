require 'spec_helper'

describe Searchlogic::NamedScopes::ColumnConditions do
  it "should be dynamically created and then cached" do
    User.singleton_class.method_defined?(:age_less_than).should == false
    User.age_less_than(5)
    User.singleton_class.method_defined?(:age_less_than).should == true
  end
  
  it "should respond to the scope" do
    User.should respond_to(:age_less_than)
  end
  
  it "should not allow conditions on non columns" do
    lambda { User.whatever_equals(2) }.should raise_error(NoMethodError)
  end
  
  context "comparison conditions" do
    it "should have equals" do
      (5..7).each { |age| User.create(:age => age) }
      nil_user = User.create
      User.age_equals(6).all.should == User.where(age: 6).to_a
      User.age_equals(nil).all.should == User.where(age: nil).to_a
    end
    
    it "should have does not equal" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_does_not_equal(6).all.should == User.where(age: [5,7]).to_a
      
      User.create!(:age => nil)
      User.age_does_not_equal(nil).all.size.should == 3
    end
    
    it "should have less than" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than(6).all.should == User.where(age: 5).to_a
    end
    
    it "should have less than or equal to" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than_or_equal_to(6).all.should == User.where(age: [5, 6]).to_a
    end
    
    it "should have greater than" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than(6).all.should == User.where(age: 7).to_a
    end
    
    it "should have greater than or equal to" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than_or_equal_to(6).all.should == User.where(age: [6, 7]).to_a
    end
  end
  
  context "wildcard conditions" do
    it "should have like" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_like("john").all.should == User.where(username: "bjohnson").to_a
    end
    
    it "should have not like" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_not_like("john").all.should == User.where(username: "thunt").to_a
    end
    
    it "should have begins with" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_begins_with("bj").all.should == User.where(username: "bjohnson").to_a
    end
    
    it "should have not begin with" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_not_begin_with("bj").all.should == User.where(username: "thunt").to_a
    end
    
    it "should have ends with" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_ends_with("son").all.should == User.where(username: "bjohnson").to_a
    end
    
    it "should have not end with" do
      %w(bjohnson thunt).each { |username| User.create(:username => username) }
      User.username_not_end_with("son").all.should == User.where(username: "thunt").to_a
    end
  end
  
  context "boolean conditions" do
    it "should have scopes for boolean columns" do
      female = User.create(:male => false)
      male = User.create(:male => true)
      User.male.all.should == [male]
      User.not_male.all.should == [female]
    end
    
    it "should have null" do
      ["bjohnson", nil].each { |username| User.create(:username => username) }
      User.username_null.all.should == User.where(username: nil).to_a
    end
    
    it "should have not null" do
      ["bjohnson", nil].each { |username| User.create(:username => username) }
      User.username_not_null.all.should == User.where(username: "bjohnson").to_a
    end
    
    it "should have empty" do
      ["bjohnson", ""].each { |username| User.create(:username => username) }
      User.username_empty.all.should == User.where(username: "").to_a
    end
    
    it "should have blank" do
      ["bjohnson", "", nil].each { |username| User.create(:username => username) }
      User.username_blank.all.should == [User.find_by_username(""), User.find_by_username(nil)]
    end
    
    it "should have not blank" do
      ["bjohnson", "", nil].each { |username| User.create(:username => username) }
      User.username_not_blank.all.should == User.where(username: "bjohnson").to_a
    end
  end
  
  context "any and all conditions" do
    it "should do nothing if no arguments are passed" do
      User.username_equals_any.to_sql.should(be_similar_sql( User.all.to_sql))
    end
  
    it "should treat an array and multiple arguments the same" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_like_any("bjohnson", "thunt").should == User.username_like_any(["bjohnson", "thunt"])
    end
    
    it "should have equals any" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_equals_any("bjohnson", "thunt").all.should == User.where(username: ["bjohnson", "thunt"]).to_a
    end
    
    # PostgreSQL does not allow null in "in" statements
    it "should have equals any and handle nils" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_equals_any("bjohnson", "thunt", nil).to_sql.should(be_similar_sql(
        User.where("users.username IN (?) OR users.username IS ?", ["bjohnson", "thunt"], nil).to_sql))
    end
    
    it "should have equals all" do
      %w(bjohnson thunt dainor).each { |username| User.create(:username => username) }
      User.username_equals_all("bjohnson", "thunt").all.should == []
    end
    
    it "should have does not equal any" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_does_not_equal_any("bjohnson", "thunt").all.should == User.where(username: ["bjohnson", "thunt", "dgainor"]).to_a
    end
    
    it "should have does not equal all" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_does_not_equal_all("bjohnson", "thunt").all.should == User.where(username: "dgainor").to_a
    end
    
    it "should have less than any" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than_any(7,6).all.should == User.where(age: [5, 6]).to_a
    end
    
    it "should have less than all" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than_all(7,6).all.should == User.where(age: 5).to_a
    end
    
    it "should have less than or equal to any" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than_or_equal_to_any(7,6).all.should == User.where(age: [5, 6, 7]).to_a
    end
    
    it "should have less than or equal to all" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_less_than_or_equal_to_all(7,6).all.should == User.where(age: [5, 6]).to_a
    end
    
    it "should have less than any" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than_any(5,6).all.should == User.where(age: [6, 7]).to_a
    end
    
    it "should have greater than all" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than_all(5,6).all.should == User.where(age: 7).to_a
    end
    
    it "should have greater than or equal to any" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than_or_equal_to_any(5,6).all.should == User.where(age: [5, 6, 7]).to_a
    end
    
    it "should have greater than or equal to all" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_greater_than_or_equal_to_all(5,6).all.should == User.where(age: [6, 7]).to_a
    end
    
    it "should have like all" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_like_all("bjohnson", "thunt").all.should == []
      User.username_like_all("n", "o").all.should == User.where(username: ["bjohnson", "dgainor"]).to_a
    end
    
    it "should have like any" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_like_any("bjohnson", "thunt").all.should == User.where(username: ["bjohnson", "thunt"]).to_a
    end
    
    it "should have begins with all" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_begins_with_all("bjohnson", "thunt").all.should == []
    end
    
    it "should have begins with any" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_begins_with_any("bj", "th").all.should == User.where(username: ["bjohnson", "thunt"]).to_a
    end
    
    it "should have ends with all" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_ends_with_all("n", "r").all.should == []
    end
    
    it "should have ends with any" do
      %w(bjohnson thunt dgainor).each { |username| User.create(:username => username) }
      User.username_ends_with_any("n", "r").all.should == User.where(username: ["bjohnson", "dgainor"]).to_a
    end
  end
  
  context "alias conditions" do
    it "should have is" do
      User.age_is(5).to_sql.should(be_similar_sql( User.age_equals(5).to_sql))
    end
    
    it "should have eq" do
      User.age_eq(5).to_sql.should(be_similar_sql( User.age_equals(5).to_sql))
    end
    
    it "should have not_equal_to" do
      User.age_not_equal_to(5).to_sql.should(be_similar_sql( User.age_does_not_equal(5).to_sql))
    end
    
    it "should have is_not" do
      User.age_is_not(5).to_sql.should(be_similar_sql( User.age_does_not_equal(5).to_sql))
    end
    
    it "should have not" do
      User.age_not(5).to_sql.should(be_similar_sql( User.age_does_not_equal(5).to_sql))
    end
    
    it "should have ne" do
      User.age_ne(5).to_sql.should(be_similar_sql( User.age_does_not_equal(5).to_sql))
    end
    
    it "should have lt" do
      User.age_lt(5).to_sql.should(be_similar_sql( User.age_less_than(5).to_sql))
    end
    
    it "should have lte" do
      User.age_lte(5).to_sql.should(be_similar_sql( User.age_less_than_or_equal_to(5).to_sql))
    end
    
    it "should have gt" do
      User.age_gt(5).to_sql.should(be_similar_sql( User.age_greater_than(5).to_sql))
    end
    
    it "should have gte" do
      User.age_gte(5).to_sql.should(be_similar_sql( User.age_greater_than_or_equal_to(5).to_sql))
    end
    
    it "should have contains" do
      User.username_contains(5).to_sql.should(be_similar_sql( User.username_like(5).to_sql))
    end
    
    it "should have contains" do
      User.username_includes(5).to_sql.should(be_similar_sql( User.username_like(5).to_sql))
    end
    
    it "should have bw" do
      User.username_bw(5).to_sql.should(be_similar_sql( User.username_begins_with(5).to_sql))
    end
    
    it "should have ew" do
      User.username_ew(5).to_sql.should(be_similar_sql( User.username_ends_with(5).to_sql))
    end
    
    it "should have nil" do
      User.username_nil.to_sql.should(be_similar_sql( User.username_nil.to_sql))
    end
  end
  
  context "group conditions" do
    it "should have in" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_in([5,6]).all.should == User.where("users.age IN (?)", [5, 6]).to_a
    end
    
    it "should have not_in" do
      (5..7).each { |age| User.create(:age => age) }
      User.age_not_in([5,6]).all.should == User.where("users.age NOT IN (?)", [5, 6]).to_a
    end
  end
  
  context "searchlogic lambda" do
    it "should be a string" do
      User.username_like("test")
      User.searchlogic_scope_impl(:username_like).searchlogic_options[:type].should == :string
    end
    
    it "should be an integer" do
      User.id_gt(10)
      User.searchlogic_scope_impl(:id_gt).searchlogic_options[:type].should == :integer
    end
    
    it "should be a float" do
      Order.total_gt(10)
      Order.searchlogic_scope_impl(:total_gt).searchlogic_options[:type].should == :float
    end
  end
  
  it "should have priorty to columns over conflicting association conditions" do
    Company.users_count_gt(10)
    User.create
    User.company_id_null.count.should == 1
    User.company_id_not_null.count.should == 0
  end
  
  it "should fix bug for issue 26" do
    count1 = User.id_ne(10).username_not_like("root").count
    count2 = User.id_ne(10).username_not_like("root").count
    count1.should == count2
  end
  
  it "should produce left outer joins" do
    User.left_outer_joins(:orders).should ==
      ["LEFT OUTER JOIN \"orders\" ON \"orders\".\"user_id\" = \"users\".\"id\""]
  end
end
