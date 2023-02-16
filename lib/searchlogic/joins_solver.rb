class Searchlogic::JoinsSolver
  autoload :Conditions, 'searchlogic/joins_solver/conditions'
  autoload :FindOptions, 'searchlogic/joins_solver/find_options'
  autoload :Group, 'searchlogic/joins_solver/group'
  autoload :Join, 'searchlogic/joins_solver/join'
  autoload :Joins, 'searchlogic/joins_solver/joins'
  autoload :Order, 'searchlogic/joins_solver/order'
  autoload :RelationAdapter, 'searchlogic/joins_solver/relation_adapter'
  autoload :Select, 'searchlogic/joins_solver/select'
  autoload :SqlString, 'searchlogic/joins_solver/sql_string'

  attr_reader :klass, :current_find_options_hash, :new_find_options_hash

  def self.conflicting_table_refs?(relation)
    RelationAdapter.new(relation).conflicting_table_refs?
  end

  # Note: Unlike #solve!, this method does *not* mutate its arguments. Instead,
  # it returns a new relation.
  def self.merge_relations(current_relation, new_relation, **merge_options)
    current_adapter = RelationAdapter.new(current_relation)
    new_adapter = RelationAdapter.new(new_relation)

    current_find_options = current_adapter.extract_find_options
    new_find_options = new_adapter.extract_find_options

    # mutates `current_find_options` and `new_find_options`
    new(current_relation.klass, current_find_options, new_find_options).solve!

    current_adapter.replace_find_options(current_find_options)
      .merge(new_adapter.replace_find_options(new_find_options), merge_options)
  end

  def initialize(klass, current_find_options_hash, new_find_options_hash)
    @klass = klass
    @current_find_options_hash = current_find_options_hash
    @new_find_options_hash = new_find_options_hash
  end

  def current_find_options
    @current_find_options ||= FindOptions.new(current_find_options_hash, klass)
  end

  def new_find_options
    @new_find_options ||= FindOptions.new(new_find_options_hash, klass)
  end

  def solve!
    new_find_options.solve_with!(current_find_options)
    current_find_options_hash.replace(current_find_options.to_hash)
    new_find_options_hash.replace(new_find_options.to_hash)
  end
end