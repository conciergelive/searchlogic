module Searchlogic
  module NamedScopes
    module Base
      def self.extended(base)
        base.class_eval do
          class_attribute :searchlogic_scopes_without_default,
            instance_reader: false,
            instance_writer: false
        end
      end

      def searchlogic_scopes
        self.searchlogic_scopes_without_default ||= {}.freeze
      end

      def searchlogic_scopes=(new_scopes)
        self.searchlogic_scopes_without_default = new_scopes
      end

      def scope(name, impl = {}, &block)
        self.searchlogic_scopes =
          self.searchlogic_scopes.merge(name.to_sym => impl).freeze

        super
      end

      def searchlogic_scope_impl(scope_name)
        return if !scope_name || !respond_to?(scope_name)

        searchlogic_scopes[scope_name.to_sym] ||
          searchlogic_scopes[condition_scope_name(scope_name)]
      end

      def searchlogic_scope_type(scope_name)
        impl = searchlogic_scope_impl(scope_name)
        return unless impl.respond_to?(:searchlogic_options)

        impl.searchlogic_options.fetch(:type, :string)
      end

      def searchlogic_scope_arity(scope_name)
        impl = searchlogic_scope_impl(scope_name)
        return unless impl.respond_to?(:searchlogic_options)

        impl.searchlogic_options.fetch(:arity) { impl.arity }
      end

      def condition?(name)
        return false if name.blank?

        searchlogic_scopes.include?(name.to_sym)
      end
    end
  end
end