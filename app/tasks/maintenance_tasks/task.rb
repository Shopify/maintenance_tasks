# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task
    extend ActiveSupport::DescendantsTracker

    class << self
      # Given the name of a Task, returns the Task subclass. Returns nil if
      # there's no task with that name.
      def named(name)
        name.constantize
      rescue NameError
        nil
      end

      # Returns a list of concrete classes that inherit from the Task
      # superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        load_constants
        descendants
      end

      # Returns the set of Run records associated with the Task.
      #
      # @return [ActiveRecord::Relation<MaintenanceTasks::Run>]
      #   the relation of Run records.
      def runs
        Run.where(task_name: name)
      end

      # Returns the active Run associated with the Task, if any.
      # An active run is defined as enqueued, running, or paused.
      #
      # @return [MaintenanceTasks::Run] the Run record.
      def active_run
        runs.active.first
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module
        namespace.constants.map { |constant| namespace.const_get(constant) }
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
