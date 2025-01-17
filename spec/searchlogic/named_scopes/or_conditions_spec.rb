require 'spec_helper'

describe Searchlogic::NamedScopes::OrConditions do
  it "should define a scope by the exact same name as requested by the code" do
    User.name_or_username_like('Test')
    User.respond_to?(:name_or_username_like).should be true
  end

  it "should match username or name" do
    User.username_or_name_like("ben").where_sql.should == 
      "WHERE (((users.username LIKE '%ben%')) OR ((users.name LIKE '%ben%')))"
  end

  it "should use the specified condition" do
    User.username_begins_with_or_name_like("ben").where_sql.should ==
      "WHERE (((users.username LIKE 'ben%')) OR ((users.name LIKE '%ben%')))"
  end

  it "should use the last specified condition" do
    User.username_or_name_like_or_id_or_age_lt(10).where_sql.should ==
      "WHERE (((users.username LIKE '%10%')) OR ((users.name LIKE '%10%')) OR ((users.id < 10)) OR ((users.age < 10)))"
  end

  it "should raise an error on unknown conditions" do
    expect { User.usernme_begins_with_or_name_like("ben") }.to raise_error(Searchlogic::NamedScopes::OrConditions::UnknownConditionError)
  end

  it "should work well with _or_equal_to" do
    User.id_less_than_or_equal_to_or_age_gt(10).where_sql.should ==
      "WHERE (((users.id <= 10)) OR ((users.age > 10)))"
  end

  it "should work well with _or_equal_to_any" do
    User.id_less_than_or_equal_to_all_or_age_gt(10).where_sql.should ==
      "WHERE (((users.id <= 10)) OR ((users.age > 10)))"
  end

  it "should work well with _or_equal_to_all" do
    User.id_less_than_or_equal_to_any_or_age_gt(10).where_sql.should ==
      "WHERE (((users.id <= 10)) OR ((users.age > 10)))"
  end

  it "should play nice with other scopes" do
    User.username_begins_with("ben").id_gt(10).age_not_nil.username_or_name_ends_with("ben").where_sql.should ==
      "WHERE (users.username LIKE 'ben%') AND (users.id > 10) AND (users.age IS NOT NULL) AND (((users.username LIKE '%ben')) OR ((users.name LIKE '%ben')))"
  end

  it "should work with boolean conditions" do
    User.male_or_name_eq("susan").where_sql.should ==
      %Q{WHERE (("users"."male" = 't') OR ((users.name = 'susan')))}
    User.not_male_or_name_eq("susan").where_sql.should ==
      %Q{WHERE (("users"."male" = 'f') OR ((users.name = 'susan')))}
    lambda { User.male_or_name_eq("susan").all }.should_not raise_error
  end

  it "should play nice with scopes on associations" do
    expect { User.name_or_company_name_like("ben") }.not_to raise_error
    User.name_or_company_name_like("ben").to_sql.should(be_similar_sql(
      "SELECT \"users\".* FROM \"users\" LEFT OUTER JOIN companies ON companies.id = users.company_id WHERE (((users.name LIKE '%ben%')) OR (((companies.name LIKE '%ben%'))))"))
    User.company_name_or_name_like("ben").to_sql.should(be_similar_sql(
      "SELECT \"users\".* FROM \"users\" LEFT OUTER JOIN companies ON companies.id = users.company_id WHERE ((((companies.name LIKE '%ben%'))) OR ((users.name LIKE '%ben%')))"))
    User.company_name_or_company_description_like("ben").to_sql.should(be_similar_sql(
      "SELECT \"users\".* FROM \"users\" INNER JOIN \"companies\" ON \"companies\".\"id\" = \"users\".\"company_id\" WHERE (((companies.name LIKE '%ben%')) OR ((companies.description LIKE '%ben%')))"))
  end

  it "should raise an error on missing condition" do
    expect { User.id_or_age(123) }.to raise_error(Searchlogic::NamedScopes::OrConditions::NoConditionSpecifiedError)
  end

  it "should not get confused by the 'or' in find_or_create_by_* methods" do
    User.create(:name => "Fred")
    if ::ActiveRecord::VERSION::MAJOR == 3
     User.find_or_create_by_name("Fred").should be_a_kind_of User
    else
      User.find_or_create_by(name: "Fred").should be_a_kind_of User
    end
  end

  it "should not get confused by the 'or' in compound find_or_create_by_* methods" do
    User.create(:name => "Fred", :username => "fredb")
    if ::ActiveRecord::VERSION::MAJOR == 3
      User.find_or_create_by_name_and_username("Fred", "fredb").should be_a_kind_of User
    else
      User.find_or_create_by(name: "Fred", username: "fredb").should be_a_kind_of User
    end
  end

  it "should work with User.search(conditions) method" do
    User.search(:username_or_name_like => 'ben').where_sql.should ==
      "WHERE (((users.username LIKE '%ben%')) OR ((users.name LIKE '%ben%')))"
  end

  it "should convert types properly when used with User.search(conditions) method" do
    User.search(:id_or_age_lte => '10').where_sql.should ==
      "WHERE (((users.id <= 10)) OR ((users.age <= 10)))"
  end
end
