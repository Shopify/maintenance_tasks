# frozen_string_literal: true

require 'csv'

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
        descendants.without(CsvTask)
      end

      # Processes one item.
      #
      # Especially useful for tests.
      #
      # @param item the item to process.
      def process(item)
        new.process(item)
      end

      # Returns the enumerator_builder for this Task.
      #
      # Especially useful for tests.
      #
      # @return the enumerator_builder.
      def enumerator_builder
        new.enumerator_builder
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

      def handles_csv
        # The contents of a CSV file to be processed by a Task.
        #
        # @return [String] the content of the CSV file to process.
        attr_accessor :csv_content
      end

      def load_constants
        namespace = MaintenanceTasks.tasks_module.safe_constantize
        return unless namespace
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end


    # @api private
    ActiveRecordEnumeratorBuilder = Struct.new(:relation) do
      def enumerator(context:)
        JobIteration::EnumeratorBuilder.new(nil).active_record_on_records(
          relation,
          cursor: context.cursor,
        )
      end
    end
    private_constant :ActiveRecordEnumeratorBuilder

    # @api private
    ArrayEnumeratorBuilder = Struct.new(:array) do
      def enumerator(context:)
        JobIteration::EnumeratorBuilder.new(nil).build_array_enumerator(
          array,
          cursor: context.cursor,
        )
      end
    end
    private_constant :ArrayEnumeratorBuilder

    # @api private
    CsvEnumeratorBuilder = Struct.new(:csv) do
      def enumerator(context:)
        JobIteration::CsvEnumerator.new(csv).rows(cursor: context.cursor)
      end
    end
    private_constant :CsvEnumeratorBuilder

    def enumerator_builder
      collection = self.collection

      case collection
      when ActiveRecord::Relation
        ActiveRecordEnumeratorBuilder.new(collection)
      when Array
        ArrayEnumeratorBuilder.new(collection)
      when CSV
        CsvEnumeratorBuilder.new(collection)
      else
        raise ArgumentError, "#{@task.class.name}#collection must be either "\
          'an Active Record Relation, Array, or CSV.'
      end
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def collection
      return CSV.new(csv_content, headers: true) if respond_to?(:csv_content)

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
      collection = self.collection

      case collection
      when ActiveRecord::Relation
        nil # assume the relation is too expensive to count
      when Array
        collection.length
      when CSV
        csv_content.count("\n") - 1
      end
    rescue NotImplementedError
      nil
    end
  end
end
