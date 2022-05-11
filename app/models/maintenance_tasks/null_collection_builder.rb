# frozen_string_literal: true

module MaintenanceTasks
  # Base strategy for building a collection-based Task to be performed.
  #
  # @api private
  class NullCollectionBuilder
    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def collection(task)
      raise NoMethodError, "#{task.class.name} must implement `collection`."
    end

    # Total count of iterations to be performed.
    #
    # Tasks override this method to define the total amount of iterations
    # expected at the start of the run. Return +nil+ if the amount is
    # undefined, or counting would be prohibitive for your database.
    #
    # @return [Integer, nil]
    def count(task)
      :no_count
    end

    # Return that the Task does not process CSV content.
    def has_csv_content?
      false
    end

    # Returns that the Task processes a collection.
    def no_collection?
      false
    end

    def has_csv_sample?
      false
    end

    def csv_sample
      raise NotImplementedError, "Only CSV tasks can have a sample CSV"
    end

    def csv_sample=(_sample)
      raise NotImplementedError, "Only CSV tasks can have a sample CSV"
    end
  end
end
