class Searchlogic::JoinsSolver::SqlString < SimpleDelegator
  attr_reader :klass

  def initialize(string, klass)
    if !string.is_a?(String)
      raise ArgumentError.new("string is not a string, you passed #{string.inspect}")
    end
    @klass = klass
    super(string)
  end

  # TODO: document what these gsubs are doing exactly
  def alias!(current_name, new_name)
    gsub!(/^(\(*?)("?)#{current_name}("?)\./, '\1\2' + new_name + '\3.')
    gsub!(/(\(| |,)(\(*?)("?)#{current_name}("?)\./, '\1\2\3' + new_name + '\4.')
  end
end