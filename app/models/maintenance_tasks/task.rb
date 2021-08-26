# frozen_string_literal: true
module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task
    extend ActiveSupport::DescendantsTracker
    include ActiveModel::Attributes
    include ActiveModel::AttributeAssignment
    include ActiveModel::Validations

    class NotFoundError < NameError; end

    # The throttle conditions for a given Task. This is provided as an array of
    # hashes, with each hash specifying two keys: throttle_condition and
    # backoff. Note that Tasks inherit conditions from their superclasses.
    #
    # @api private
    class_attribute :throttle_conditions, default: []

    class_attribute :collection_builder_strategy,
      default: NullCollectionBuilder.new

    class << self
      # Finds a Task with the given name.
      #
      # @param name [String] the name of the Task to be found.
      #
      # @return [Task] the Task with the given name.
      #
      # @raise [NotFoundError] if a Task with the given name does not exist.
      def named(name)
        task = name.safe_constantize
        raise NotFoundError.new("Task #{name} not found.", name) unless task
        unless task.is_a?(Class) && task < Task
          raise NotFoundError.new("#{name} is not a Task.", name)
        end
        task
      end

      # Returns a list of concrete classes that inherit from the Task
      # superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        load_constants
        descendants
      end

      # Make this Task a task that handles CSV.
      #
      # An input to upload a CSV will be added in the form to start a Run. The
      # collection and count method are implemented.
      def csv_collection
        if !defined?(ActiveStorage) || !ActiveStorage::Attachment.table_exists?
          raise NotImplementedError, "Active Storage needs to be installed\n"\
            "To resolve this issue run: bin/rails active_storage:install"
        end
        self.collection_builder_strategy = CsvCollectionBuilder.new
      end

      # Returns whether the Task handles CSV.
      #
      # @return [Boolean] whether the Task handles CSV.
      def has_csv_content?
        collection_builder_strategy.has_csv_content?
      end

      # Processes one item.
      #
      # Especially useful for tests.
      #
      # @param item the item to process.
      def process(item)
        new.process(item)
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

      # Add a condition under which this Task will be throttled.
      #
      # @param backoff [ActiveSupport::Duration] optionally, a custom backoff
      #   can be specified. This is the time to wait before retrying the Task.
      #   If no value is specified, it defaults to 30 seconds.
      # @yieldreturn [Boolean] where the throttle condition is being met,
      #   indicating that the Task should throttle.
      def throttle_on(backoff: 30.seconds, &condition)
        self.throttle_conditions += [
          { throttle_on: condition, backoff: backoff },
        ]
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module.safe_constantize
        return unless namespace
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end

    # The contents of a CSV file to be processed by a Task.
    #
    # @return [String] the content of the CSV file to process.
    def csv_content
      raise NoMethodError unless has_csv_content?

      @csv_content
    end

    # Set the contents of a CSV file to be processed by a Task.
    #
    # @param csv_content [String] the content of the CSV file to process.
    def csv_content=(csv_content)
      raise NoMethodError unless has_csv_content?

      @csv_content = csv_content
    end

    # Returns whether the Task handles CSV.
    #
    # @return [Boolean] whether the Task handles CSV.
    def has_csv_content?
      self.class.has_csv_content?
    end

    # The collection to be processed, delegated to the strategy.
    #
    # @return the collection.
    def collection
      self.class.collection_builder_strategy.collection(self)
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @param _item [Object] the current item from the enumerator being iterated.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def process(_item)
      raise NoMethodError, "#{self.class.name} must implement `process`."
    end

    # Total count of iterations to be performed, delegated to the strategy.
    #
    # @return [Integer, nil]
    def count
      self.class.collection_builder_strategy.count(self)
    end
  end
end
