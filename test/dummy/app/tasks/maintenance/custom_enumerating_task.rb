# frozen_string_literal: true

module Maintenance
  class CustomEnumeratingTask < MaintenanceTasks::Task
    def enumerator_builder(cursor:)
      drop = cursor.nil? ? 0 : cursor.to_i + 1

      [:a, :b, :c].lazy.with_index.drop(drop)
    end

    def count
      3
    end

    def process(letter)
      Rails.logger.debug("letter: #{letter}")
    end
  end
end
