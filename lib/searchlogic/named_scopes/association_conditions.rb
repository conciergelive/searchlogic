module Searchlogic
  module NamedScopes
    # Handles dynamically creating named scopes for associations. See the README for a detailed explanation.
    module AssociationConditions
      def condition?(name) # :nodoc:
        super || association_condition?(name)
      end

      private
        def association_condition?(name)
          !association_condition_details(name).nil? unless name.to_s.downcase.match("_or_")
        end

        # We need to try and create other conditions first so that we give priority to conflicting names.
        # Such as having a column name with the exact same name as an association condition.
        def create_condition(name)
          if result = super
            result
          elsif details = association_condition_details(name)
            create_association_condition(details[:association], details[:condition], details[:poly_class])
          end
        end

        def association_condition_details(name, last_condition = nil)
          non_poly_assocs = reflect_on_all_associations.reject { |assoc| assoc.options[:polymorphic] }.sort { |a, b| b.name.to_s.size <=> a.name.to_s.size }
          poly_assocs = reflect_on_all_associations.reject { |assoc| !assoc.options[:polymorphic] }.sort { |a, b| b.name.to_s.size <=> a.name.to_s.size }
          return nil if non_poly_assocs.empty? && poly_assocs.empty?

          name_with_condition = [name, last_condition].compact.join('_')

          association_name = nil
          poly_type = nil
          condition = nil

          if name_with_condition.to_s =~ /^(#{non_poly_assocs.collect(&:name).join("|")})_(\w+)$/ && non_poly_assocs.present?
            association_name = $1
            condition = $2
          elsif name_with_condition.to_s =~ /^(#{poly_assocs.collect(&:name).join("|")})_(\w+?)_type_(\w+)$/
            association_name = $1
            poly_type = $2
            condition = $3
          end

          if association_name && condition
            association = reflect_on_association(association_name.to_sym)
            klass = poly_type ? poly_type.camelcase.constantize : association.klass
            if klass.condition?(condition)
              {:association => association, :poly_class => poly_type && klass, :condition => condition}
            else
              nil
            end
          end
        end

        def create_association_condition(association, condition_name, poly_class = nil)
          name = [association.name, poly_class && "#{poly_class.name.underscore}_type", condition_name].compact.join("_")
          scope(name, association_condition_options(association, condition_name, poly_class))
        end

        def association_condition_options(association, scope_name, poly_class = nil)
          target = poly_class || association.klass

          join_condition =
            if poly_class
              inner_polymorphic_join(poly_class.name.underscore, as: association.name)
            else
              association.name
            end

          type = target.searchlogic_scope_type(scope_name)
          arity = target.searchlogic_scope_arity(scope_name)

          impl = searchlogic_lambda(type, arity: arity) do |*args|
            target_scope = target.public_send(scope_name, *args)

            scoped_with_isolated_table_references do
              joins(join_condition).merge(target_scope)
            end
          end
          
          impl
        end
    end
  end
end
