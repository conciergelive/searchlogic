module Searchlogic
  module ActiveRecord
    # Adds methods that give extra information about a classes named scopes.
    module NamedScopeTools
      def self.extended(base)
        base.class_eval do
          class_attribute :_scopes,
            instance_reader: false,
            instance_writer: false
        end
      end

      # Retrieves the options passed when creating the respective named scope. Ex:
      #
      #   scope :whatever, :conditions => {:column => value}
      #
      # This method will return:
      #
      #   :conditions => {:column => value}
      #
      # ActiveRecord hides this internally in a Proc, so we have to try and pull it out with this
      # method.
      def named_scope_options(name)
        return unless name # TODO: Why do we need this now?
        respond_to?(name) # TODO: Why do we nedd this now too?!

        key = scopes.key?(name.to_sym) ? name.to_sym : condition_scope_name(name)

        if key && scopes[key]
          scopes[key]
        else
          nil
        end
      end

      # TODO: Remove this whole mess after figuring out why we need to do this
      def scope(name, options = {}, &block)
        self.scopes = self.scopes.merge(name.to_sym => options).freeze

        super
      end

      def scopes
        self._scopes ||= {}
      end

      def scopes=(new_scopes)
        self._scopes = new_scopes
      end

      # The arity for a named scope's proc is important, because we use the arity
      # to determine if the condition should be ignored when calling the search method.
      # If the condition is false and the arity is 0, then we skip it all together. Ex:
      #
      #   User.named_scope :age_is_4, :conditions => {:age => 4}
      #   User.search(:age_is_4 => false) == User.all
      #   User.search(:age_is_4 => true) == User.all(:conditions => {:age => 4})
      #
      # We also use it when trying to "copy" the underlying named scope for association
      # conditions. This way our aliased scope accepts the same number of parameters for
      # the underlying scope.
      def named_scope_arity(name)
        options = named_scope_options(name)
        options.respond_to?(:arity) ? options.arity : nil
      end

      # A convenience method for creating inner join sql to that your inner joins
      # are consistent with how Active Record creates them. Basically a tool for
      # you to use when writing your own named scopes. This way you know for sure
      # that duplicate joins will be removed when chaining scopes together that
      # use the same join.
      #
      # Also, don't worry about breaking up the joins or retriving multiple joins.
      # ActiveRecord will remove dupilicate joins and Searchlogic assists ActiveRecord in
      # breaking up your joins so that they are unique.
      def inner_joins(association_name)
        unscoped.joins(association_name).join_sources.map(&:to_sql)
      end

      # A convenience methods to create a join on a polymorphic associations target.
      # Ex:
      #
      # Audit.belong_to :auditable, :polymorphic => true
      # User.has_many :audits, :as => :auditable
      #
      # Audit.inner_polymorphic_join(:user, :as => :auditable) # =>
      #   "INNER JOINER users ON users.id = audits.auditable_id AND audits.auditable_type = 'User'"
      #
      # This is used internally by searchlogic to handle accessing conditions on polymorphic associations.
      def inner_polymorphic_join(target, options = {})
        options[:on] ||= table_name
        options[:on_table_name] ||= connection.quote_table_name(options[:on])
        options[:target_table] ||= connection.quote_table_name(target.to_s.pluralize)
        options[:as] ||= "owner"
        postgres = ::ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
        "INNER JOIN #{options[:target_table]} ON #{options[:target_table]}.id = #{options[:on_table_name]}.#{options[:as]}_id AND " +
          "#{options[:on_table_name]}.#{options[:as]}_type = #{postgres ? "E" : ""}'#{target.to_s.camelize}'"
      end

      # See inner_joins. Does the same thing except creates LEFT OUTER joins.
      def left_outer_joins(association_name)
        inner_joins(association_name).map { |join_sql| join_sql.gsub(/INNER JOIN/, 'LEFT OUTER JOIN') }
      end
    end
  end
end