module Searchlogic
  module NamedScopes
    # Handles dynamically creating named scopes for 'OR' conditions. Please see the README for a more
    # detailed explanation.
    module OrConditions
      class NoConditionSpecifiedError < StandardError; end
      class UnknownConditionError < StandardError; end

      def condition?(name) # :nodoc:
        super || or_condition?(name)
      end

      def named_scope_options(name) # :nodoc:
        super || super(or_conditions(name).try(:join, "_or_"))
      end

      private
        def or_condition?(name)
          !or_conditions(name).nil?
        end

        def create_condition(name)
          if conditions = or_conditions(name)
            create_or_condition(conditions)
            alias_name = conditions.join("_or_")
            singleton_class.alias_method name, conditions.join("_or_") if name != alias_name
          else
            super
          end
        end

        def or_conditions(name)
          # TODO: Why do we need this now?
          return if name.start_with?('find_')
          # First determine if we should even work on the name, we want to be as quick as possible
          # with this.
          if (parts = split_or_condition(name)).size > 1
            conditions = interpolate_or_conditions(parts)
            if conditions.any?
              conditions
            else
              nil
            end
          end
        end

        def split_or_condition(name)
          parts = name.to_s.split("_or_")
          new_parts = []
          parts.each do |part|
            if part =~ /^equal_to(_any|_all)?$/
              new_parts << new_parts.pop + "_or_equal_to"
            else
              new_parts << part
            end
          end
          new_parts
        end

        # The purpose of this method is to convert the method name parts into actual condition names.
        #
        # Example:
        #
        #   ["first_name", "last_name_like"]
        #   => ["first_name_like", "last_name_like"]
        #
        #   ["id_gt", "first_name_begins_with", "last_name", "middle_name_like"]
        #   => ["id_gt", "first_name_begins_with", "last_name_like", "middle_name_like"]
        #
        # Basically if a column is specified without a condition the next condition in the list
        # is what will be used. Once we are able to get a consistent list of conditions we can easily
        # create a scope for it.
        def interpolate_or_conditions(parts)
          conditions = []
          last_condition = nil

          parts.reverse.each do |part|
            if details = condition_details(part)
              # We are a searchlogic defined scope
              conditions << "#{details[:column]}_#{details[:condition]}"
              last_condition = details[:condition]
            elsif association_details = association_condition_details(part, last_condition)
              path = full_association_path(part, last_condition, association_details[:association])
              conditions << "#{path[:path].join("_").to_sym}_#{path[:column]}_#{path[:condition]}"
              last_condition = path[:condition] || nil
            elsif column_condition?(part)
              # We are a custom scope
              conditions << part
            elsif column_names.include?(part)
              # we are a column, use the last condition
              if last_condition.nil?
                raise NoConditionSpecifiedError.new("The '#{part}' column doesn't know which condition to use, if you use an exact column " +
                  "name you need to specify a condition sometime after (ex: id_or_created_at_lt), where id would use the 'lt' condition.")
              end

              conditions << "#{part}_#{last_condition}"
            else
              raise UnknownConditionError.new("The condition '#{part}' is not a valid condition, we could not find any scopes that match this.")
            end
          end

          conditions.reverse
        end

        def full_association_path(part, last_condition, given_assoc)
          path = [given_assoc.name]
          part.sub!(/^#{given_assoc.name}_/, "")
          klass = self
          while klass = klass.send(:reflect_on_association, given_assoc.name)
            klass = klass.klass
            if details = klass.send(:association_condition_details, part, last_condition)
              path << details[:association].name
              part = details[:condition]
              given_assoc = details[:association]
            elsif details = klass.send(:condition_details, part)
              return { :path => path, :column => details[:column], :condition => details[:condition] }
            end
          end
          {:path => path, :column => part, :condition => last_condition}
        end

        def create_or_condition(scopes)
          scope_name = scopes.join("_or_")

          scope scope_name, ->(*args) {
            relations = scopes.map { |scope| unscoped.public_send(scope, *args) }

            if (uniq_joins = extract_uniq_joins_values(relations))
              joins(uniq_joins).where(combine_where_sql(relations))
            else
              where(combine_subquery_sql(relations))
            end
          }
        end

        def extract_uniq_joins_values(relations)
          uniq_joins, *other_joins = relations.map(&:joins_values).uniq
          uniq_joins unless other_joins.any?
        end

        def combine_where_sql(relations)
          "(#{relations.map(&method(:relation_where_sql)).join(') OR (')})"
        end

        def relation_where_sql(relation)
          relation.where_sql.gsub(/\AWHERE /, '')
        end

        def combine_subquery_sql(relations)
          relations.map(&method(:relation_subquery_sql)).join(' OR ')
        end

        def relation_subquery_sql(relation)
          "#{table_name}.id IN (#{relation.select(:id).to_sql})"
        end
    end
  end
end
