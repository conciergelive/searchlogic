require "spec_helper"

describe Searchlogic::JoinsSolver::RelationAdapter do
  describe '.extract_table_ref_from_join' do
    subject { described_class.extract_table_ref_from_join(join_clause_sql) }

    context 'with a plain join to a table' do
      let(:join_clause_sql) { "JOIN foo ON 1=1" }

      it { subject.should eql("foo") }
    end

    context 'with a join to a table with an alias' do
      let(:join_clause_sql) { "JOIN foo AS bar ON 1=1" }

      it { subject.should eql("bar") }
    end

    context 'with a join to a subquery with an alias' do
      let(:join_clause_sql) { "JOIN (SELECT VERSION()) AS bar ON 1=1" }

      it { subject.should eql("bar") }
    end
  end
end