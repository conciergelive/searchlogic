module Searchlogic
  class Search
    module ToYaml
      def self.included(klass)
        klass.class_eval do
          include InstanceMethods
        end
      end

      module InstanceMethods
        def encode_with(coder)
          coder.tag = "!ruby/object:Searchlogic::Search"
          coder['class_name'] = klass.name
          coder['current_scope'] = current_scope
          coder['conditions'] = conditions
        end

        def init_with(coder)
          self.klass = coder['class_name'].constantize
          self.current_scope = coder['current_scope']
          @conditions ||= {}
          self.conditions = coder['conditions']
          self
        end
      end
    end
  end
end
