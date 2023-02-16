class Searchlogic::JoinsSolver::Conditions < Searchlogic::JoinsSolver::SqlString
  def initialize(sql, klass)
    super(klass.send(:sanitize_sql, sql), klass)
  end

  def ==(other_obj)
    case other_obj
    when self.class
      compare_obj == other_obj.compare_obj
    else
      compare_obj == other_obj
    end
  end

  def compare_obj
    sql_for_compare.split(/ AND /i).collect { |p| p.split(" = ").collect { |s| normalize_part(s) }.sort }.sort
  end

  private
    def sql_for_compare
      @sql_for_compare ||= if useless_parenthesis?
        gsub(/\(|\)/, '')
      else
        self
      end
    end

    def useless_parenthesis?
      return @useless_parenthesis if defined?(@useless_parenthesis)
      @useless_parenthesis = scan(/\(/).size == 1
    end

    def normalize_part(s)
      s.gsub("E'", "'")
    end
end