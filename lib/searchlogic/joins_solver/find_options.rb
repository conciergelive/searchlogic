class Searchlogic::JoinsSolver::FindOptions
  attr_reader :conditions, :find_options, :group, :joins, :klass, :order, :select

  def initialize(find_options, klass)
    if !find_options.is_a?(Hash)
      raise ArgumentError.new("find_options must be a Hash, you passed #{find_options.inspect}")
    end
    @klass = klass
    @select = find_options[:select] && Searchlogic::JoinsSolver::Select.new(find_options[:select], klass)
    @joins = Searchlogic::JoinsSolver::Joins.new([find_options[:joins]].flatten.compact, klass)
    @conditions = find_options[:conditions].blank? ? nil : Searchlogic::JoinsSolver::Conditions.new(find_options[:conditions], klass)
    @order = find_options[:order] && Searchlogic::JoinsSolver::Order.new(find_options[:order], klass)
    @group = find_options[:group] && Searchlogic::JoinsSolver::Group.new(find_options[:group], klass)
    @find_options = find_options
  end

  def alias!(current_name, new_name)
    if other_join_with_same_name = joins.detect { |join| join.name == new_name }
      alias!(new_name, generate_alias(other_join_with_same_name.table_name, joins))
    end

    select&.alias!(current_name, new_name)
    joins&.alias!(current_name, new_name)
    conditions&.alias!(current_name, new_name)
    order&.alias!(current_name, new_name)
    group&.alias!(current_name, new_name)
  end

  def solve_with!(current_find_options)
    current_find_options.joins.delete_if { |j| j.name == klass.table_name }

    if joins
      joins.each_with_index do |join, index|
        #same_join = current_find_options.joins.index(join)
        if same_join_index = find_same_join_index(join, current_find_options.joins)
          same_join = current_find_options.joins[same_join_index]

          # does the current join have a different name? if so, lets update it to match the one we already have
          if join.name != same_join.name
            alias!(join.name, same_join.name)
          end

          if join.should_replace?(same_join)
            # ex: need to replace a left outer join with an inner join
            current_find_options.joins[same_join_index] = join
          else
            # ex: condition order is irrelevant so make the new join conform so AR removes duplicates
            joins[index] = same_join
          end

        elsif find_conflict_join_index(join, current_find_options.joins)
          # we have 2 joins with the same name that are not the same
          alias!(join.name, generate_alias(join.table_name, joins + current_find_options.joins))
        end
      end
    end
  end

  def to_hash
    h = find_options
    h[:select] = select.to_s if select
    h[:joins] = joins.collect(&:to_s) if joins
    h[:conditions] = conditions.to_s if conditions
    h[:order] = order.to_s if order
    h[:group] = group.to_s if group
    h
  end

  def inspect
    "#<JoinsSolver::FindOptions #to_hash => #{to_hash.inspect}>"
  end

  private
    def generate_alias(table_name, existing_joins)
      (1..Float::INFINITY).each do |i|
        new_name = "#{table_name}_#{i}"
        if !existing_joins.collect(&:name).include?(new_name)
          return new_name
        end
      end
      nil
    end

    def find_same_join_index(join, other_joins)
      other_joins.index(join)
    end

    def find_conflict_join_index(join, other_joins)
      other_joins.detect { |other_join| join.name == other_join.name }
    end
end