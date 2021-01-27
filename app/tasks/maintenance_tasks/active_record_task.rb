# frozen_string_literal: true

module MaintenanceTasks
  class ActiveRecordTask < Task
    # TODO: define replacement for Task.collection, delegating to instance
    # Probably simplest to make this an ActiveSupport::Concern

    # TODO: specify abstract_class

    EnumeratorBuilder = Struct.new(:collection) do
      def enumerator(context:)
        enumerator_builder.active_record_on_records(collection, cursor: context.cursor)
      end
    end

    def enumerator_builder
      collection = self.collection
      assert_relation!(collection)

      EnumeratorBuilder.new(collection)
    end

    def collection
      raise NotImplementedError, 'consumers implement this'
    end

    def count
      collection.count
    end

    # Easily lends itself to adding batching
    # def batch_size
    #   1
    # end

    private

    def assert_relation!(collection)
      return if collection.is_a?(ActiveRecord::Relation)

      raise(
        ArgumentError,
        "#{self.class.name}#collection must be an ActiveRecord::Relation",
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
