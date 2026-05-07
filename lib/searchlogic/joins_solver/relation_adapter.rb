class Searchlogic::JoinsSolver::RelationAdapter
  JOIN_CLAUSE_REGEXP = %r{
    JOIN                                  # the JOIN keyword
    \s+                                   # whitespace
    (?:                                   # either...
      (?:"?(?<source_table_name>\w+)"?)   #   a possibly quoted identifier
      |                                   #   ...or...
      (?<subquery>                        #   something in balanced parens
        \(                                #     an open paren
          (?:                             #     any amount of...
            [^\(\)]                       #       something that is not parens
            |                             #       ...or...
            \g<subquery>                  #       something in balanced parens
          )*                              #
        \)                                #     a closing paren
      )                                   #
    )                                     #
    \s+                                   # whitespace
    (?:                                   # maybe...
      (?:                                 #   maybe...
        AS                                #     the AS keyword
        \s+                               #     whitespace
      )?                                  #
      "?(?<alias>\w+)"?                   #   a possibly quoted identifier
      \s+                                 #   whitespace
    )?                                    #
    ON                                    # the ON keyword
  }xi

  def self.extract_table_ref_from_join(join_clause_sql)
    match = JOIN_CLAUSE_REGEXP.match(join_clause_sql)
    raise NotImplementedError, "Parse JOIN: #{join_clause_sql}" unless match
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

    @visitor = relation.connection.visitor
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
    # `:bind` is dropped alongside `:where` because `conditions_sql` inlines
    # bind values directly into the rebuilt WHERE string; leaving the original
    # bind_values on the relation would cause PG to receive params with no
    # matching `$N` placeholder.
    new_relation = relation.except(:select, :joins, :where, :order, :group, :bind)

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
    return nil if wheres.empty?

    if defined?(Arel::Collectors::Bind)
      render_conditions_with_inlined_binds
    else
      to_sql_list(wheres, ' AND ')
    end
  end

  # Renders all where nodes in a single pass through an `Arel::Collectors::Bind`
  # so the collector preserves BindParam AST nodes as parts. We then call
  # `compile` to substitute them with quoted values from `relation.bind_values`.
  #
  # The previous implementation rendered each where through the connection's
  # Arel visitor with an `SQLString` collector, which emits `$1`, `$2`, ...
  # placeholders for BindParam nodes. The bind metadata was then lost when the
  # resulting string was re-applied via `.where(conditions_sql)` — leaving raw
  # `$N` tokens in the SQL that no longer corresponded to any bound parameter.
  def render_conditions_with_inlined_binds
    collector = Arel::Collectors::Bind.new
    rendered_any = false

    wheres.each do |node|
      case node
      when String
        next if node.empty?
        collector << ' AND ' if rendered_any
        collector << node
      else
        collector << ' AND ' if rendered_any
        visitor.accept(node, collector)
      end
      rendered_any = true
    end

    return nil unless rendered_any

    conn = relation.connection
    quoted_binds = relation.bind_values.map { |bv| conn.quote(*bv.reverse) }
    collector.compile(quoted_binds).presence
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
    case node
    when String then node.presence
    else
      if defined?(Arel::Collectors::SQLString)
        collector = Arel::Collectors::SQLString.new
        visitor.accept(node, collector).value.presence
      else
        visitor.accept(node).presence
      end
    end
  end
end