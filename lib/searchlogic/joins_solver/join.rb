class Searchlogic::JoinsSolver::Join
  include Comparable
  attr_reader :sql, :klass

  def initialize(sql, klass)
    @klass = klass
    @sql = sql.gsub('"', '').strip
  end

  def type
    return @type if defined?(@type)
    match = sql.match(/^(.*) JOIN/i)
    @type = match && match[1].downcase.to_sym
  end

  def should_replace?(other_join)
    other_join.type != :inner && type == :inner
  end

  def alias!(current_name, new_name)
    return if current_name == new_name

    if name == current_name
      change_name!(new_name)
    end

    alias_conditions!(current_name, new_name)
  end

  def apply_alias!(new_name)
    alias!(name, new_name)
  end

  def aliased?
    names.size > 1
  end

  def name
    names.last # split gets table aliases
  end

  def table_name
    names.first
  end

  def ==(other_obj)
    case other_obj
    when self.class
      # check table names at least for efficiency to avoid the below for joins we know wont match
      table_name == other_obj.table_name && compare_obj == other_obj.compare_obj
    else
      compare_obj == other_obj
    end
  end

  # The idea here is to normalize the object for comparison with another join. Eliminate the things
  # we don't want to factor in and then compare them.
  def compare_obj
    return @compare_obj if defined?(@compare_obj)
    obj_for_compare = clone
    # aliases shouldnt matter when comparing, so we normalize the aliases to make it moot
    obj_for_compare.apply_alias!("this_feels_dirty_123")
    declaration, conditions = obj_for_compare.sql.split(/ ON /i)
    @compare_obj = [table_name, Searchlogic::JoinsSolver::Conditions.new(conditions, klass)]
  end

  def to_s
    sql
  end

  def inspect
    "#<JoinsSolver::Join @sql=#{sql}>"
  end

  def clone
    self.class.new(sql, klass)
  end

  private
    def change_name!(new_name)
      new_names = [table_name, new_name].uniq.join(" ")
      sql.gsub!(names_regex, "JOIN #{new_names} ON ")
    end

    def alias_conditions!(current_name, new_name)
      sql.gsub!(/ (\(*?)("?)#{current_name}("?)\./, ' \1\2' + new_name + '\3.')
    end

    def names_regex
      @names_regex ||= /JOIN (.*?) ON /i
    end

    def names_match
      names_match ||= sql.match(names_regex)
    end

    def names
      names ||= names_match ? names_match[1].split(" ") : []
    end
end