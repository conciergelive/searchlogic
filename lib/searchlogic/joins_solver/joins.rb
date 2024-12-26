class Searchlogic::JoinsSolver::Joins < SimpleDelegator
  JOIN_TYPES = [
    "INNER JOIN",
    "LEFT OUTER JOIN",
    "RIGHT OUTER JOIN",
    "FULL OUTER JOIN"
  ]

  attr_reader :klass

  def initialize(joins, klass)
    if !joins.is_a?(Array)
      raise ArgumentError.new("joins must be an array, you passed #{joins.inspect}")
    end
    @klass = klass
    super(joins)
    normalize_to_strings!
    normalize_to_single_joins!
    normalize_to_delegated_joins!
  end

  def alias!(current_name, new_name)
    each { |join| join.alias!(current_name, new_name) }
  end

  private
    def normalize_to_strings!
      if !all? { |join| join.is_a?(String) }
        replace(klass.inner_joins(to_a)) # use to_a, inner joins does a strict check on the object type
      end
    end

    def normalize_to_single_joins!
      replace(collect { |join| split_join(join) }.flatten)
    end

    # Takes a single string of multiple joins and returns back an array. That's the goal here.
    def split_join(sql)
      joins = []
      sorted_join_types = JOIN_TYPES.sort { |a,b| b.length <=> a.length }
      sql.split(/(#{sorted_join_types.join("|")})/).select { |part| !part.strip.blank? }.in_groups_of(2) do |group|
        joins << group.join
      end
      joins
    end

    def normalize_to_delegated_joins!
      replace(collect { |join| Searchlogic::JoinsSolver::Join.new(join, klass) })
    end
end