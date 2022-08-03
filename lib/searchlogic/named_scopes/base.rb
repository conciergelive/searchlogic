module Searchlogic
  module NamedScopes
    module Base
      def condition?(name)
        return false if name.blank?

        scopes.include?(name.to_sym)
      end
    end
  end
end