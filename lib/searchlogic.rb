require 'active_support'
require 'active_record'
require "searchlogic/version"
require "searchlogic/core_ext/proc"
require "searchlogic/core_ext/object"
require "searchlogic/joins_solver"
require "searchlogic/active_record/join_sql_tools"
require "searchlogic/named_scopes/base"
require "searchlogic/named_scopes/column_conditions"
require "searchlogic/named_scopes/ordering"
require "searchlogic/named_scopes/association_conditions"
require "searchlogic/named_scopes/association_ordering"
require "searchlogic/named_scopes/alias_scope"
require "searchlogic/named_scopes/or_conditions"
require "searchlogic/search/base"
require "searchlogic/search/conditions"
require "searchlogic/search/date_parts"
require "searchlogic/search/implementation"
require "searchlogic/search/method_missing"
require "searchlogic/search/ordering"
require "searchlogic/search/scopes"
require "searchlogic/search/to_yaml"
require "searchlogic/search/unknown_condition_error"
require "searchlogic/search"

Proc.send(:include, Searchlogic::CoreExt::Proc)
Object.send(:include, Searchlogic::CoreExt::Object)

ActiveRecord::Base.extend(Searchlogic::ActiveRecord::JoinSqlTools)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::Base)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::ColumnConditions)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::AssociationConditions)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::AssociationOrdering)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::Ordering)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::AliasScope)
ActiveRecord::Base.extend(Searchlogic::NamedScopes::OrConditions)
ActiveRecord::Base.extend(Searchlogic::Search::Implementation)

# Try to use the search method, if it's available. Thinking sphinx and other plugins
# like to use that method as well.
if !ActiveRecord::Base.respond_to?(:search)
  ActiveRecord::Base.class_eval { class << self; alias_method :search, :searchlogic; end }
end

if defined?(ActionController)
  require "searchlogic/rails_helpers"
  ActionController::Base.helper(Searchlogic::RailsHelpers)
end
