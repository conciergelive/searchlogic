module Searchlogic
  class Search
    module Scopes
      private
        def scope_name(condition_name)
          condition_name && normalize_scope_name(condition_name)
        end

        def scope?(scope_name)
          klass.condition?(scope_name)
        end

        def scope_options(name)
          klass.searchlogic_scope_impl(name)
        end
    end
  end
end