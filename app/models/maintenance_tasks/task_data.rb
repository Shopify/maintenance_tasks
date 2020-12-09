# frozen_string_literal: true
module MaintenanceTasks
  # Class that represents the data related to a Task. Such information can be
  # sourced from a Task or from existing Run records for a Task that was since
  # deleted.
  #
  # Instances of this class replace a Task class instance in cases where we
  # don't need the actual Task subclass.
  #
  # @api private
  class TaskData
    class << self
      # Initializes a Task Data by name, raising if the Task does not exist.
      #
      # For the purpose of this method, a Task does not exist if it's deleted
      # and doesn't have a Run. While technically, it could have existed and
      # been deleted since, if it never had a Run we may as well consider it
      # non-existent since we don't have interesting data to show.
      #
      # @param name [String] the name of the Task subclass.
      # @return [TaskData] a Task Data instance.
      # @raise [Task::NotFoundError] if the Task does not exist and doesn't have
      #   a Run.
      def find(name)
        task_data = new(name)
        task_data.last_run || Task.named(name)
        task_data
      end

      # Returns a list of Task Data objects that represent the available Tasks.
      #
      # @return [Array<TaskData>] the list of Task Data.
      def available_tasks
        Task.available_tasks.map { |task| TaskData.new(task.name) }
      end
    end

    # Initializes a Task Data with a name.
    #
    # @param name [String] the name of the Task subclass.
    def initialize(name)
      @name = name
    end

    # @return [String] the name of the Task.
    attr_reader :name

    alias_method :to_s, :name

    # Returns the set of Run records associated with the Task.
    #
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>]
    #   the relation of Run records.
    def runs
      Run.where(task_name: name)
    end

    # Retrieves the latest Run associated with the Task.
    #
    # @return [MaintenanceTasks::Run] the Run record.
    # @return [nil] if there are no Runs associated with the Task.
    def last_run
      return @last_run if defined?(@last_run)
      @last_run = runs.last
    end

    # @return [Boolean] whether the Task has been deleted.
    def deleted?
      Task.named(name)
      false
    rescue Task::NotFoundError
      true
    end
  end
  private_constant :TaskData
end
