# frozen_string_literal: true

module MaintenanceTasks
  class ActiveRecordTask < Task
    # TODO: define replacement for Task.collection, delegating to instance
    # Probably simplest to make this an ActiveSupport::Concern

    # TODO: Specify abstract_class

    def enumerator(cursor:)
      collection = self.collection
      assert_array!(collection)

      enumerator_builder.array(collection, cursor: cursor)
    end

    def collection
      raise NotImplementedError, 'consumers implement this'
    end

    def count
      collection.length
    end

    private

    def assert_array!(collection)
      return if collection.is_a?(Array)

      raise(
        ArgumentError,
        "#{self.class.name}#collection must be an Array",
      )
    end

    # Convenience method to allow tasks define enumerators with cursors for
    # compatibility with Job Iteration.
    #
    # @return [JobIteration::EnumeratorBuilder] instance of an enumerator
    #   builder available to tasks.
    def enumerator_builder
      JobIteration.enumerator_builder.new(nil)
    end
  end
end
