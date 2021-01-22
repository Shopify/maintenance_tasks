# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task
    extend ActiveSupport::DescendantsTracker

    class NotFoundError < NameError; end

    class << self
      # Finds a Task with the given name.
      #
      # @param name [String] the name of the Task to be found.
      #
      # @return [Task] the Task with the given name.
      #
      # @raise [NotFoundError] if a Task with the given name does not exist.
      def named(name)
        name.constantize
      rescue NameError
        raise NotFoundError.new("Task #{name} not found.", name)
      end

      # Returns a list of concrete classes that inherit from the Task
      # superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        load_constants
        descendants
      end

      # Processes one item.
      #
      # Especially useful for tests.
      #
      # @param item the item to process.
      def process(item)
        new.process(item)
      end

      # Returns the enumerator for this Task.
      #
      # Especially useful for tests.
      #
      # @return the enumerator.
      def enumerator(context:) # TODO: Test this
        new.enumerator(context: context)
      end

      # Returns the collection for this Task.
      #
      # Especially useful for tests.
      #
      # @return the collection.
      def collection
        new.collection
      end

      # Returns the count of items for this Task.
      #
      # Especially useful for tests.
      #
      # @return the count of items.
      def count
        new.count
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module.safe_constantize
        return unless namespace
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end

    # Generate an enumerator suitable for enumerating over the Task's
    # collection.
    #
    # Subclasses wanting to iterate over collections without built-in support
    # should override this and return a custom enumerator. An execution context
    # is provided, allowing the cursor to be used to resume iteration.
    #
    #     class SomeAPITask < Task
    #       def enumerator(context:
    #         SomeAPI.each_record(after: job.cursor).lazy.map do |api_record|
    #           [api_record, api_record.id]
    #         end
    #       end
    #
    #       def process(resource)
    #         puts "Processed #{resource}"
    #       end
    #     end
    #
    # @param context [EnumeratorContext] context for the enumerator, including
    # a cursor
    # @return the enumerator.
    def enumerator(context:)
      collection = self.collection

      case collection
      when ActiveRecord::Relation
        context.enumerator_builder.active_record_on_records(
          collection,
          cursor: context.cursor,
        )
      when Array
        context.enumerator_builder.build_array_enumerator(
          collection,
          cursor: context.cursor,
        )
      when CSV
        JobIteration::CsvEnumerator.new(collection).rows(cursor: context.cursor)
      else
        raise ArgumentError, "#{self.class.name}#collection must be either "\
          'an Active Record Relation, an Array, or a CSV.'
      end
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def collection
      raise NotImplementedError,
        "#{self.class.name} must implement `collection`."
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @param _item [Object] the current item from the enumerator being iterated.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def process(_item)
      raise NotImplementedError,
        "#{self.class.name} must implement `process`."
    end

    # Total count of iterations to be performed.
    #
    # Tasks override this method to define the total amount of iterations
    # expected at the start of the run. Return +nil+ if the amount is
    # undefined, or counting would be prohibitive for your database.
    #
    # @return [Integer, nil]
    def count
    end
  end
end
