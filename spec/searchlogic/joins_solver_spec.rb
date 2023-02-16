require "spec_helper"

describe Searchlogic::JoinsSolver do
  describe '#solve!' do
    let(:current_hash) { {} }
    let(:new_hash) { {} }
    let(:joins_solver) { Searchlogic::JoinsSolver.new(Company, current_hash, new_hash) }

    before do
      allow(joins_solver.current_find_options).to receive(:to_hash).and_return({:current => :value})
      allow(joins_solver.new_find_options).to receive(:to_hash).and_return({:new => :value})
      joins_solver.solve!
    end

    context 'current_hash' do
      subject { current_hash }
      it { should eq({:current => :value}) }
    end

    context 'new_hash' do
      subject { new_hash }
      it { should eq({:new => :value}) }
    end
  end

  let(:company_join) { "INNER JOIN companies ON companies.id = users.company_id" }
  let(:company_join_with_extra_condition) { "INNER JOIN companies ON companies.id = users.company_id AND companies.name = 'Concierge Live'" }
  let(:company_join_with_reverse_extra_condition) { "INNER JOIN companies ON companies.name = 'Concierge Live' AND companies.id = users.company_id" }
  let(:company_join_with_alias) { "INNER JOIN companies aliased_companies ON aliased_companies.id = users.company_id" }
  let(:quoted_company_join) { "INNER JOIN \"companies\" ON \"companies\".id = \"users\".company_id" }
  let(:left_outer_company_join) { "LEFT OUTER JOIN companies ON companies.id = users.company_id" }

  context "#solve!" do
    it "properly merges duplicate joins" do
      current_find_options = {:joins => company_join}
      new_find_options = {:joins => company_join}
      Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
      expect(new_find_options).to eq({:joins => [company_join]})
    end

    it "converts symbols to strings" do
      current_find_options = {:joins => company_join}
      new_find_options = {:joins => :company}
      Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
      expect(new_find_options).to eq({:joins => [company_join]})
    end

    context "comparing" do
      it "doesn't care about quotes" do
        current_find_options = {:joins => company_join}
        new_find_options = {:joins => quoted_company_join}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join]})
      end

      it "doesnt care about case" do
        current_find_options = {:joins => company_join}
        new_find_options = {:joins => company_join.downcase}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join]})
      end

      it "doesnt care about white space padding" do
        current_find_options = {:joins => " #{company_join} "}
        new_find_options = {:joins => " \n#{company_join}\t "}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join]})
      end

      it "doesnt care about condition order" do
        current_find_options = {:joins => company_join_with_extra_condition}
        new_find_options = {:joins => company_join_with_reverse_extra_condition}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_extra_condition]})
      end

      it "doesnt care if multiple joins are in a single string" do
        current_find_options = {:joins => company_join_with_extra_condition}
        new_find_options = {:joins => "#{company_join_with_extra_condition} #{company_join_with_alias}"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_extra_condition, company_join_with_alias]})
      end

      it "doesn't care about has many through symbol joins" do
        joins = ["INNER JOIN user_group_memberships ON user_group_memberships.user_group_id = user_groups.id", "INNER JOIN users ON users.id = user_group_memberships.user_id"]
        current_find_options = {:joins => joins}
        new_find_options = {:joins => :users}
        Searchlogic::JoinsSolver.new(UserGroup, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => joins})
      end

      it "doesnt care about join type and gives inner joins priority" do
        current_find_options = {:joins => left_outer_company_join}
        new_find_options = {:joins => company_join}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(current_find_options).to eq({:joins => [company_join]})
      end
    end

    context 'aliasing' do
      it "aliases different joins with the same name" do
        current_find_options = {:joins => company_join}
        new_find_options = {:joins => company_join_with_extra_condition}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => ["INNER JOIN companies companies_1 ON companies_1.id = users.company_id AND companies_1.name = 'Concierge Live'"]})
      end

      it "uses aliases already established" do
        current_find_options = {:joins => [company_join_with_extra_condition, company_join_with_alias]}
        new_find_options = {:joins => company_join}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias]})
      end

      it "carries over to the group" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :group => "companies.name"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :group => "aliased_companies.name"})
      end

      it "carries over to the dependent joins" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => [company_join, "INNER JOIN departments ON departments.company_id = companies.id"]}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias, "INNER JOIN departments ON departments.company_id = aliased_companies.id"]})
      end

      it "carries over to the select" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :select => "companies.name"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :select => "aliased_companies.name"})
      end

      it "carries over to the conditions" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :conditions => "companies.name = 'Concierge Live'"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :conditions => "aliased_companies.name = 'Concierge Live'"})
      end

      it "carries over to the conditions with parenthesis" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => "INNER JOIN companies ON (companies.id = users.company_id)", :conditions => "(companies.name = 'Concierge Live')"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :conditions => "(aliased_companies.name = 'Concierge Live')"})
      end

      it "carries over to the conditions with multiple parenthesis" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => "INNER JOIN companies ON (companies.id = users.company_id)", :conditions => "((companies.name = 'Concierge Live'))"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :conditions => "((aliased_companies.name = 'Concierge Live'))"})
      end

      it "carries over to the conditions array" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :conditions => ["companies.name = ?", 'Concierge Live']}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :conditions => "aliased_companies.name = 'Concierge Live'"})
      end

      it "carries over to the order" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :order => "companies.name ASC"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :order => "aliased_companies.name ASC"})
      end

      it "carries over to the group" do
        current_find_options = {:joins => company_join_with_alias}
        new_find_options = {:joins => company_join, :group => "companies.name"}
        Searchlogic::JoinsSolver.new(User, current_find_options, new_find_options).solve!
        expect(new_find_options).to eq({:joins => [company_join_with_alias], :group => "aliased_companies.name"})
      end
    end
  end
end