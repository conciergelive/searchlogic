module Searchlogic
  class Search
    module MethodMissing
      def respond_to_missing?(*args)
        super || scope?(normalize_scope_name(args.first))
      rescue Searchlogic::NamedScopes::OrConditions::UnknownConditionError
        false
      end

      private
        def method_missing(name, *args, &block)
          condition_name = condition_name(name)
          scope_name = scope_name(condition_name)

          if setter?(name)
            if scope?(scope_name)
              if args.size == 1
                write_condition(
                  condition_name,
                  type_cast(
                    args.first,
                    cast_type(scope_name),
                    scope_options(scope_name).respond_to?(:searchlogic_options) ? scope_options(scope_name).searchlogic_options : {}
                  )
                )
              else
                write_condition(condition_name, args)
              end
            else
              raise UnknownConditionError.new(condition_name)
            end
          elsif scope?(scope_name) && args.size <= 1
            if args.size == 0
              read_condition(condition_name)
            else
              send("#{condition_name}=", *args)
              self
            end
          else
            scope = conditions_array.inject(current_scope) do |scope, condition|
              scope_name, value = condition
              scope_name = normalize_scope_name(scope_name)
              klass.send(scope_name, value) if !klass.respond_to?(scope_name)
              arity = klass.searchlogic_scope_arity(scope_name)

              if !arity || arity == 0
                if value == true
                  scope.send(scope_name)
                else
                  scope
                end
              elsif arity == -1
                scope.send(scope_name, *(value.is_a?(Array) ? value : [value]))
              else
                scope.send(scope_name, value)
              end
            end

            if order
              if scope?(order)
                scope = scope.except(:order).send(order) if scope.respond_to?(order)
              else
                scope = scope.send(:"ascend_by_#{order}") if scope.respond_to?(:"ascend_by_#{order}")
              end
            end

            scope.send(name, *args, &block)
          end
        end

        def normalize_scope_name(scope_name)
          case
          when klass.searchlogic_scopes.key?(scope_name.to_sym) then scope_name.to_sym
          when klass.column_names.include?(scope_name.to_s) then "#{scope_name}_equals".to_sym
          else scope_name.to_sym
          end
        end

        def setter?(name)
          !(name.to_s =~ /=$/).nil?
        end

        def condition_name(name)
          condition = name.to_s.match(/(\w+)=?$/)
          condition ? condition[1].to_sym : nil
        end

        def cast_type(name)
          arity = klass.searchlogic_scope_arity(name)
          if !arity || arity == 0
            :boolean
          else
            klass.searchlogic_scope_type(name)
          end
        end

        def type_cast(value, type, options = {})
          case value
          when Array
            value.collect { |v| type_cast(v, type) }.uniq
          when Range
            Range.new(type_cast(value.first, type), type_cast(value.last, type))
          else
            casted_value = legacy_active_record_type_cast(type, value)

            if Time.zone && casted_value.is_a?(Time)
              if value.is_a?(String)
                # if its a string, we should assume the user means the local time
                # we need to update the object to include the proper time zone without changing
                # the time
                (casted_value + (Time.zone.utc_offset * -1)).in_time_zone(Time.zone)
              else
                casted_value.in_time_zone
              end
            else
              casted_value
            end
          end
        end

        ARColumn = ::ActiveRecord::ConnectionAdapters::Column

        def legacy_active_record_type_cast(type, value)
          return nil if value.nil?

          case type
            when :string    then value
            when :text      then value
            when :integer   then value.to_i rescue value ? 1 : 0
            when :float     then value.to_f
            when :decimal   then ARColumn.value_to_decimal(value)
            when :datetime  then ARColumn.string_to_time(value)
            when :timestamp then ARColumn.string_to_time(value)
            when :time      then ARColumn.string_to_dummy_time(value)
            when :date      then ARColumn.string_to_date(value)
            when :binary    then ARColumn.binary_to_string(value)
            when :boolean   then ARColumn.value_to_boolean(value)
            else value
          end
        end
    end
  end
end