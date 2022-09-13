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
        task_data.active_runs.load
        task_data.has_any_run? || Task.named(name)
        task_data
      end

      # Returns a list of sorted Task Data objects that represent the
      # available Tasks.
      #
      # Tasks are sorted by category, and within a category, by Task name.
      # Determining a Task's category requires their latest Run records.
      # Two queries are done to get the currently active and completed Run
      # records, and Task Data instances are initialized with these last_run
      # values.
      #
      # @return [Array<TaskData>] the list of Task Data.
      def available_tasks
        tasks = []

        task_names = Task.available_tasks.map(&:name)

        active_runs = Run.with_attached_csv.active.where(task_name: task_names)
        active_runs.each do |run|
          tasks << TaskData.new(run.task_name, run)
          task_names.delete(run.task_name)
        end

        completed_runs = Run.completed.where(task_name: task_names)
        last_runs = Run.with_attached_csv.where(
          id: completed_runs.select("MAX(id) as id").group(:task_name),
        )
        task_names.map do |task_name|
          last_run = last_runs.find { |run| run.task_name == task_name }
          tasks << TaskData.new(task_name, last_run)
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
    alias_method :last_run, :related_run

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

    # Returns the status of the latest active or completed Run, if present.
    # If the Task does not have any Runs, the Task status is `new`.
    #
    # @return [String] the Task status.
    def status
      last_run&.status || "new"
    end

    # Retrieves the Task's category, which is one of active, new, or completed.
    #
    # @return [Symbol] the category of the Task.
    def category
      if last_run.present? && last_run.active?
        :active
      elsif last_run.nil?
        :new
      else
        :completed
      end
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
