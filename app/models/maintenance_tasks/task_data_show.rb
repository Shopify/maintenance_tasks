# frozen_string_literal: true

module MaintenanceTasks
  # Class that represents the data related to a Task. Such information can be
  # sourced from a Task or from existing Run records for a Task that was since
  # deleted. This class contains detailed information such as the source code,
  # associated runs, parameters, etc.
  #
  # Instances of this class replace a Task class instance in cases where we
  # don't need the actual Task subclass.
  #
  # @api private
  class TaskDataShow
    # Initializes a Task Data with a name and optionally a related run.
    #
    # @param name [String] the name of the Task subclass.
    def initialize(name)
      @name = name
    end

    # @return [String] the name of the Task.
    attr_reader :name
    alias_method :to_s, :name

    # The Task's source code.
    #
    # @return [String] the contents of the file which defines the Task.
    # @return [nil] if the Task file was deleted.
    def code
      return if deleted?

      task = Task.named(name)
      file = if Object.respond_to?(:const_source_location)
        Object.const_source_location(task.name).first
      else
        task.instance_method(:process).source_location.first
      end
      File.read(file)
    end

    # Returns the set of currently active Run records associated with the Task.
    #
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>] the relation of
    #   active Run records.
    def active_runs
      @active_runs ||= runs.active
    end

    # Returns the set of completed Run records associated with the Task.
    # This collection represents a historic of past Runs for information
    # purposes, since the base for Task Data information comes
    # primarily from currently active runs.
    #
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>] the relation of
    #   completed Run records.
    def completed_runs
      @completed_runs ||= runs.completed
    end

    # @return [Boolean] whether the Task has been deleted.
    def deleted?
      Task.named(name)
      false
    rescue Task::NotFoundError
      true
    end

    # @return [Boolean] whether the Task inherits from CsvTask.
    def csv_task?
      !deleted? && Task.named(name).has_csv_content?
    end

    # @return [Array<String>] the names of parameters the Task accepts.
    def parameter_names
      if deleted?
        []
      else
        Task.named(name).attribute_names
      end
    end

    # @return [MaintenanceTasks::Task, nil] an instance of the Task class.
    # @return [nil] if the Task file was deleted.
    def new
      return if deleted?

      MaintenanceTasks::Task.named(name).new
    end

    private

    def runs
      Run.where(task_name: name).with_attached_csv.order(created_at: :desc)
    end
  end
end
