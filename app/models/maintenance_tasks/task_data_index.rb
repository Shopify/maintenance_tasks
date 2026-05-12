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
      # Tasks are sorted by category, and within a category, by the most
      # recent Run's creation time (most recent first). New tasks with no
      # Run history fall back to alphabetical order by name.
      # Determining a Task's category requires their latest Run records.
      # Two queries are done to get the currently active and completed Run
      # records, and Task Data instances are initialized with these related run
      # values.
      #
      # @return [Array<TaskDataIndex>] the list of Task Data.
      def available_tasks
        tasks = []

        task_names = Task.load_all.map(&:name)

        active_runs = Run.with_attached_csv.active.where(task_name: task_names)
        active_runs.each do |run|
          tasks << TaskDataIndex.new(run.task_name, run)
          task_names.delete(run.task_name)
        end

        completed_runs = Run.completed.where(task_name: task_names)
        last_runs = Run.with_attached_csv
          .where(created_at: completed_runs.select("MAX(created_at) as created_at").group(:task_name))
        task_names.map do |task_name|
          last_run = last_runs.find { |run| run.task_name == task_name }
          tasks << TaskDataIndex.new(task_name, last_run)
        end

        # Most-recent-first by Run creation time; new tasks (no Run) sort
        # together by name. Status is a final tiebreaker to keep ordering
        # stable across database adapters when a Task has multiple active
        # Runs created at the same time.
        tasks.sort_by! do |task|
          [-(task.related_run&.created_at&.to_f || 0), task.name, task.status]
        end
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

    # Delegates to the related run's stale? method when available.
    #
    # @return [Boolean] whether the related run is stale.
    def stale?
      return false unless related_run.present?

      related_run.stale?
    end

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
