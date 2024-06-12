# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task
    extend ActiveSupport::DescendantsTracker
    include ActiveSupport::Callbacks
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

    # @api private
    class_attribute :collection_builder_strategy, default: NullCollectionBuilder.new

    define_callbacks :start, :complete, :error, :cancel, :pause, :interrupt

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

      # Loads and returns a list of concrete classes that inherit
      # from the Task superclass.
      #
      # @return [Array<Class>] the list of classes.
      def load_all
        load_constants
        descendants
      end

      # Loads and returns a list of concrete classes that inherit
      # from the Task superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        warn(<<~MSG.squish, category: :deprecated)
          MaintenanceTasks::Task.available_tasks is deprecated and will be
          removed from maintenance-tasks 3.0.0. Use .load_all instead.
        MSG
        load_all
      end

      # Make this Task a task that handles CSV.
      #
      # @param in_batches [Integer] optionally, supply a batch size if the CSV
      #   should be processed in batches.
      # @param csv_options [Hash] optionally, supply options for the CSV parser.
      #   If not given, defaults to: <code>{ headers: true }</code>
      # @see https://ruby-doc.org/3.3.0/stdlibs/csv/CSV.html#class-CSV-label-Options+for+Parsing
      #
      # An input to upload a CSV will be added in the form to start a Run. The
      # collection and count method are implemented.
      def csv_collection(in_batches: nil, **csv_options)
        unless defined?(ActiveStorage)
          raise NotImplementedError, "Active Storage needs to be installed\n" \
            "To resolve this issue run: bin/rails active_storage:install"
        end

        csv_options[:headers] = true unless csv_options.key?(:headers)
        csv_options[:encoding] ||= Encoding.default_external
        self.collection_builder_strategy = if in_batches
          BatchCsvCollectionBuilder.new(in_batches, **csv_options)
        else
          CsvCollectionBuilder.new(**csv_options)
        end
      end

      # Make this a Task that calls #process once, instead of iterating over
      # a collection.
      def no_collection
        self.collection_builder_strategy = MaintenanceTasks::NoCollectionBuilder.new
      end

      delegate :has_csv_content?, :no_collection?, to: :collection_builder_strategy

      # Processes one item.
      #
      # Especially useful for tests.
      #
      # @param args [Object, nil] the item to process
      def process(*args)
        new.process(*args)
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
      # @param backoff [ActiveSupport::Duration, #call] a custom backoff
      #   can be specified. This is the time to wait before retrying the Task,
      #   defaulting to 30 seconds. If provided as a Duration, the backoff is
      #   wrapped in a proc. Alternatively,an object responding to call can be
      #   used. It must return an ActiveSupport::Duration.
      # @yieldreturn [Boolean] where the throttle condition is being met,
      #   indicating that the Task should throttle.
      def throttle_on(backoff: 30.seconds, &condition)
        backoff_as_proc = backoff
        backoff_as_proc = -> { backoff } unless backoff.respond_to?(:call)

        self.throttle_conditions += [{ throttle_on: condition, backoff: backoff_as_proc }]
      end

      # Initialize a callback to run after the task starts.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_start(*filter_list, &block)
        set_callback(:start, :after, *filter_list, &block)
      end

      # Initialize a callback to run after the task completes.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_complete(*filter_list, &block)
        set_callback(:complete, :after, *filter_list, &block)
      end

      # Initialize a callback to run after the task pauses.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_pause(*filter_list, &block)
        set_callback(:pause, :after, *filter_list, &block)
      end

      # Initialize a callback to run after the task is interrupted.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_interrupt(*filter_list, &block)
        set_callback(:interrupt, :after, *filter_list, &block)
      end

      # Initialize a callback to run after the task is cancelled.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_cancel(*filter_list, &block)
        set_callback(:cancel, :after, *filter_list, &block)
      end

      # Initialize a callback to run after the task produces an error.
      #
      # @param filter_list apply filters to the callback
      #   (see https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html#method-i-set_callback)
      def after_error(*filter_list, &block)
        set_callback(:error, :after, *filter_list, &block)
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module.safe_constantize
        return unless namespace

        Rails.autoloaders.main.eager_load_namespace(namespace)
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

    # Returns whether the Task is collection-less.
    #
    # @return [Boolean] whether the Task is collection-less.
    def no_collection?
      self.class.no_collection?
    end

    # The collection to be processed, delegated to the strategy.
    #
    # @return the collection.
    def collection
      self.class.collection_builder_strategy.collection(self)
    end

    # The columns used to build the `ORDER BY` clause of the query for iteration.
    #
    # If cursor_columns returns nil, the query is ordered by the primary key.
    # If cursor columns values change during an iteration, records may be skipped or yielded multiple times.
    # More details in the documentation of JobIteration::EnumeratorBuilder.build_active_record_enumerator_on_records:
    # https://www.rubydoc.info/gems/job-iteration/JobIteration/EnumeratorBuilder#build_active_record_enumerator_on_records-instance_method
    #
    # @return the cursor_columns.
    def cursor_columns
      nil
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

    # Default enumerator builder. You may override this method to return any
    # Enumerator yielding pairs of `[item, item_cursor]`.
    #
    # @param cursor [String, nil] cursor position to resume from, or nil on
    #   initial call.
    #
    # @return [Enumerator]
    def enumerator_builder(cursor:)
      nil
    end
  end
end
