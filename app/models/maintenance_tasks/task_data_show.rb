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
    class << self
      # Initializes a Task Data by name, raising if the Task does not exist.
      #
      # For the purpose of this method, a Task does not exist if it's deleted
      # and doesn't have a Run. While technically, it could have existed and
      # been deleted since, if it never had a Run we may as well consider it
      # non-existent since we don't have interesting data to show.
      #
      # @param name [String] the name of the Task subclass.
      # @return [TaskDataShow] a Task Data instance.
      # @raise [Task::NotFoundError] if the Task does not exist and doesn't have
      #   a Run.
      def find(name)
        task_data = new(name)
        task_data.active_runs.load
        task_data.has_any_run? || Task.named(name)
        task_data
      end
    end

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

    # @return [Boolean] whether the Task has any Run.
    # @api private
    def has_any_run?
      active_runs.any? || completed_runs.any?
    end

    private

    def runs
      Run.where(task_name: name).with_attached_csv.order(created_at: :desc)
    end
  end
end
