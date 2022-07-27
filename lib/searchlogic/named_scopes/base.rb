module Searchlogic
  module NamedScopes
    module Base
      def condition?(name)
        return false if name.blank?

        valid_scope_names.include?(name.to_sym)
      end

      def scope(name, *)
        super.tap { valid_scope_names.add(name.to_sym) }
      end

      private

      # TODO: This should be a class attribute
      def valid_scope_names
        @valid_scope_names ||= Set.new
      end
    end
  end
end