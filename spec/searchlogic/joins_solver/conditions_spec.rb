require "spec_helper"

describe Searchlogic::JoinsSolver::Conditions do
  describe '#==' do
    let(:sql) { nil }
    let(:conditions) { Searchlogic::JoinsSolver::Conditions.new(sql, User) }
    let(:other_sql) { nil }
    let(:other_conditions) { Searchlogic::JoinsSolver::Conditions.new(other_sql, User) }
    subject { conditions == other_conditions }

    context 'exactly the same' do
      let(:sql) { "users.name = 'Ben'" }
      let(:other_sql) { "users.name = 'Ben'" }
      it { should be true }
    end

    context 'same, but in reverse order' do
      let(:sql) { "users.name = 'Ben' AND users.age = 12" }
      let(:other_sql) { "users.age = 12 AND users.name = 'Ben'" }
      it { should be true }
    end

    context 'doesn\'t care about case for operands' do
      let(:sql) { "users.name = 'Ben' AND users.age = 12" }
      let(:other_sql) { "users.age = 12 and users.name = 'Ben'" }
      it { should be true }
    end

    context 'same but with a prefixed E' do
      let(:sql) { "users.name = E'Ben'" }
      let(:other_sql) { "users.name = 'Ben'" }
      it { should be true }
    end
  end
end