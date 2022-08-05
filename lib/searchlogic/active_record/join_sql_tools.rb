module Searchlogic
  module ActiveRecord
    module JoinSqlTools
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