# frozen_string_literal: true

module MaintenanceTasks
  # Strategy for building a Task that has no collection. These Tasks
  # consist of a single iteration.
  #
  # @api private
  class NoCollectionBuilder
    # Specifies that this task does not process a collection.
    def collection(_task)
      :no_collection
    end

    # The number of rows to be processed. Always returns 1.
    def count(_task)
      1
    end

    # Return that the Task does not process CSV content.
    def has_csv_content?
      false
    end
  end
end
