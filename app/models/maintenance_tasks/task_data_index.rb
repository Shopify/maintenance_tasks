# frozen_string_literal: true

module MaintenanceTasks
  # Class that represents the data related to a Task. Such information can be
  # sourced from a Task or from existing Run records for a Task that was since
  # deleted. This class contains higher-level information about the Task, such
  # as its status and category.
  #
  # Instances of this class replace a Task class instance in cases where we
  # don't need the actual Task subclass.
  #
  # @api private
  class TaskDataIndex
    class << self
      # Returns a list of sorted Task Data objects that represent the
      # available Tasks.
      #
      # Tasks are sorted by category, and within a category, by Task name.
      # Determining a Task's category requires their latest Run records.
      # Two queries are done to get the currently active and completed Run
      # records, and Task Data instances are initialized with these related run
      # values.
      #
      # @return [Array<TaskDataIndex>] the list of Task Data.
      def available_tasks
        tasks = []

        task_names = Task.available_tasks.map(&:name)

        active_runs = Run.with_attached_csv.active.where(task_name: task_names)
        active_runs.each do |run|
          tasks << TaskDataIndex.new(run.task_name, run)
          task_names.delete(run.task_name)
        end

        completed_runs = Run.completed.where(task_name: task_names)
        last_runs = Run.with_attached_csv.where(id: completed_runs.select("MAX(id) as id").group(:task_name))
        task_names.map do |task_name|
          last_run = last_runs.find { |run| run.task_name == task_name }
          tasks << TaskDataIndex.new(task_name, last_run)
        end

        # We add an additional sorting key (status) to avoid possible
        # inconsistencies across database adapters when a Task has
        # multiple active Runs.
        tasks.sort_by! { |task| [task.name, task.status] }
      end
    end

    # Initializes a Task Data with a name and optionally a related run.
    #
    # @param name [String] the name of the Task subclass.
    # @param related_run [MaintenanceTasks::Run] optionally, a Run record to
    #   set for the Task.
    def initialize(name, related_run = nil)
      @name = name
      @related_run = related_run
    end

    # @return [String] the name of the Task.
    attr_reader :name
    attr_reader :related_run

    alias_method :to_s, :name

    # Returns the status of the latest active or completed Run, if present.
    # If the Task does not have any Runs, the Task status is `new`.
    #
    # @return [String] the Task status.
    def status
      related_run&.status || "new"
    end

    # Retrieves the Task's category, which is one of active, new, or completed.
    #
    # @return [Symbol] the category of the Task.
    def category
      if related_run.present? && related_run.active?
        :active
      elsif related_run.nil?
        :new
      else
        :completed
      end
    end
  end
end
