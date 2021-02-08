# frozen_string_literal: true
module Maintenance
  class CustomEnumeratingTask < MaintenanceTasks::Task
    class CustomEnumeratorBuilder
      def enumerator(context:)
        drop = context.cursor.nil? ? 0 : context.cursor + 1

        Array.new(3) { |index| [index, index] }.lazy.drop(drop)
      end
    end

    def enumerator_builder
      CustomEnumeratorBuilder.new
    end

    def count
      3
    end

    def process(_)
    end
  end
end
