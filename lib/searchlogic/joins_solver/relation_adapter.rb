class Searchlogic::JoinsSolver::RelationAdapter
  JOIN_CLAUSE_REGEXP = %r{
    JOIN
    \s+
    "?(?<source_table_name>\w+)"?
    (
      \s+
      (
        AS
        \s+
      )?
      "?(?<alias>\w+)"?
    )?
    \s+
    ON
  }xi

  def self.extract_table_ref_from_join(join_clause_sql)
    match = JOIN_CLAUSE_REGEXP.match(join_clause_sql)
    raise NotImplementedError unless match
    match[:alias] || match[:source_table_name]
  end

  attr_reader :relation, :core, :visitor

  delegate :arel, :table_name, :from_value, :select_values, to: :relation
  delegate :join_sources, :orders, to: :arel
  delegate :projections, :wheres, :groups, to: :core

  def initialize(relation)
    @relation = relation

    @core, *other_cores = arel.ast.cores
    raise NotImplementedError if other_cores.any?

    @visitor = Arel::Visitors::ToSql.new(relation.connection)
  end

  def conflicting_table_refs?
    table_refs = [from_table_ref].to_set
    !joined_table_refs.all?(&table_refs.method(:add?))
  end

  def extract_find_options
    {
      select: select_sql,
      joins: joins_clauses_sql,
      conditions: conditions_sql,
      order: order_sql,
      group: group_sql,
    }
  end

  def replace_find_options(new_find_options)
    new_relation = relation.except(:select, :joins, :where, :order, :group)

    if (select = new_find_options[:select])
      new_relation = new_relation.select(select)
    end

    if (joins = new_find_options[:joins])
      new_relation = new_relation.joins(joins)
    end

    if (conditions = new_find_options[:conditions])
      new_relation = new_relation.where(conditions)
    end

    if (order = new_find_options[:order])
      new_relation = new_relation.order(order)
    end

    if (group = new_find_options[:group])
      new_relation = new_relation.group(group)
    end

    new_relation
  end

  private

  def from_table_ref
    raise NotImplementedError if from_value

    table_name
  end

  def joined_table_refs
    joins_clauses_sql.map(&self.class.method(:extract_table_ref_from_join))
  end

  # The select clause is a special case because `projections` will still have a
  # value (table_name.*) even if the underlying relation has no `select_values`.
  def select_sql
    to_sql_list(projections, ', ') if select_values.any?
  end

  def joins_clauses_sql
    to_sql_array(join_sources)
  end

  def conditions_sql
    to_sql_list(wheres, ' AND ')
  end

  def order_sql
    to_sql_list(orders, ', ')
  end

  def group_sql
    to_sql_list(groups, ', ')
  end

  def to_sql_list(nodes, separator_sql)
    to_sql_array(nodes).join(separator_sql).presence
  end

  def to_sql_array(nodes)
    nodes.map(&method(:to_sql)).compact
  end

  def to_sql(node)
    visitor.accept(node).presence
  end
end