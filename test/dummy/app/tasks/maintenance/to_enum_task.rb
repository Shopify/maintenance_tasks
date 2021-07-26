# frozen_string_literal: true

module Maintenance
  class ToEnumTask < MaintenanceTasks::Task
    class Collection
      def to_enumerable(cursor:)
        array.to_enum
      end

      def count
        array.count
      end

      private

      def array
        [1, 2, 3]
      end
    end

    def collection
      Collection.new
    end

    def count
      collection.count
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end
  end
end
