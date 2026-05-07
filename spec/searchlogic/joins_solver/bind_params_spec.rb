require "spec_helper"

# These specs demonstrate that on Rails 4.x, when a relation carries
# `bind_values` (e.g. it was built from an association like `company.users`),
# the JoinsSolver renders the WHERE clause via the connection's prepared-
# statement-aware Arel visitor. That visitor emits `$1`, `$2`, ... placeholders
# for BindParam nodes, which then leak into the conditions string applied via
# `.where(conditions_sql)`. The bind metadata is lost from the AST, so the
# generated SQL carries placeholders that no longer line up with any binds.
#
# With `prepared_statements: true` (Rails' default), the original
# `relation.bind_values` happen to ride along through `except(:where)` and
# PostgreSQL resolves `$1` against them — so the breakage is silent. With
# `prepared_statements: false`, the adapter sends an empty params array and
# PG raises PG::ProtocolViolation: bind message supplies 0 parameters, but
# prepared statement requires 1.
describe "Searchlogic::JoinsSolver bind-param handling" do
  before do
    @company = Company.create!(name: "Acme")
    @user = User.create!(company: @company, username: "alice", age: 30)
    @order = Order.create!(user: @user, total: 50, taxes: 5)
  end

  describe Searchlogic::JoinsSolver::RelationAdapter do
    describe "#extract_find_options" do
      it "does not leak $N placeholders into the conditions string" do
        relation = @company.users
        # Sanity check: this association relation does carry a bind value.
        expect(relation.bind_values).not_to be_empty

        adapter = described_class.new(relation)
        conditions = adapter.extract_find_options[:conditions]

        expect(conditions).to be_present
        expect(conditions).not_to match(/\$\d+/),
          "expected conditions not to contain prepared-statement placeholders, got: #{conditions.inspect}"
      end

      it "inlines the bind value(s) into the conditions string" do
        relation = @company.users
        adapter = described_class.new(relation)
        conditions = adapter.extract_find_options[:conditions]

        expect(conditions).to include(@company.id.to_s)
      end
    end
  end

  describe Searchlogic::JoinsSolver, ".merge_relations" do
    it "produces SQL with no leftover $N placeholders" do
      merged = described_class.merge_relations(
        @company.users,
        User.age_gt(10),
      )

      expect(merged.to_sql).not_to match(/\$\d+/)
    end

    # Mirrors the production failure mode: connections with prepared statements
    # disabled (e.g. PgBouncer transaction-pool clients) send an empty params
    # array, so the leaked `$1` in the SQL has nothing to bind to and PG raises.
    context "on a connection with prepared_statements disabled" do
      around do |example|
        original = ActiveRecord::Base.connection.instance_variable_get(:@prepared_statements)
        ActiveRecord::Base.connection.instance_variable_set(:@prepared_statements, false)
        begin
          example.run
        ensure
          ActiveRecord::Base.connection.instance_variable_set(:@prepared_statements, original)
        end
      end

      it "executes without raising PG::ProtocolViolation" do
        merged = described_class.merge_relations(
          @company.users,
          User.age_gt(10),
        )

        expect { merged.to_a }.not_to raise_error
      end
    end
  end
end
