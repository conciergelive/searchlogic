module Searchlogic
  class Search
    module Ordering
      attr_accessor :order

      # Returns the column we are currently ordering by
      def ordering_by
        @ordering_by ||= order && order.to_s.match(/^(ascend|descend)_by_(.*)$/)&.[](2)
      end

      def ordering_direction
        @ordering_direction ||= order && order.to_s.match(/^(ascend|descend)_by_/)&.[](1)
      end
    end
  end
end