# frozen_string_literal: true

require "timeout"

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
    TIMEOUT = 15

    # Initializes a Task Data with a name.
    #
    # @param name [String] the name of the Task subclass.
    # @param runs_cursor [String, nil] the cursor for the runs page.
    # @param arguments [Hash, nil] the Task arguments.
    def initialize(name, runs_cursor: nil, arguments: nil)
      @name = name
      @arguments = arguments
      @runs_page = RunsPage.new(completed_runs, runs_cursor)
    end

    class << self
      # Prepares a Task Data from a task name.
      #
      # @param name [String] the name of the Task subclass.
      # @param runs_cursor [String, nil] the cursor for the runs page.
      # @param arguments [Hash, nil] the Task arguments.
      # @raise [Task::NotFoundError] if the Task doesn't have runs (for the given cursor) and doesn't exist.
      def prepare(name, runs_cursor: nil, arguments: nil)
        new(name, runs_cursor:, arguments:)
          .load_active_runs
          .ensure_task_exists
      end
    end

    # @return [String] the name of the Task.
    attr_reader :name
    alias_method :to_s, :name

    # @return [RunsPage] the current page of completed runs, based on the cursor
    #   passed in initialize.
    attr_reader :runs_page

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

    # @return [Boolean] whether the task data needs to be refreshed.
    def refresh?
      active_runs.any?
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

    # @return [Boolean] whether the Task is collection-less.
    def no_collection?
      !deleted? && Task.named(name).no_collection?
    end

    # @return [Array<String>] the names of parameters the Task accepts.
    def parameter_names
      if deleted?
        []
      else
        Task.named(name).attribute_names
      end
    end

    # @return [Integer] the count of items to be processed.
    # @return [nil] if the count is unavailable (e.g. CSV tasks where the
    #   collection depends on uploaded file content, tasks whose collection
    #   requires arguments, or when the query times out).
    def count
      return if deleted?
      return if csv_task?

      task_instance = new
      return if task_instance.nil?

      Timeout.timeout(TIMEOUT) do
        result = task_instance.count
        result = task_instance.collection.count if result == :no_count
        result if result.is_a?(Integer)
      end
    rescue StandardError
      nil
    end

    # @return [MaintenanceTasks::Task] an instance of the Task class.
    # @return [nil] if the Task file was deleted.
    def new
      return if deleted?

      task = MaintenanceTasks::Task.named(name).new
      begin
        task.assign_attributes(@arguments) if @arguments
      rescue ActiveModel::UnknownAttributeError
        # nothing to do
      end
      task
    end

    # Preloads the records from the active_runs ActiveRecord::Relation
    # @return [self]
    def load_active_runs
      active_runs.load
      self
    end

    # @raise [Task::NotFoundError] if the Task doesn't have Runs (for the given cursor) and doesn't exist.
    # @return [self]
    def ensure_task_exists
      if active_runs.none? && runs_page.records.none?
        Task.named(name)
      end
      self
    end

    private

    def runs
      Run.where(task_name: name).with_attached_csv.order(created_at: :desc)
    end
  end
end
