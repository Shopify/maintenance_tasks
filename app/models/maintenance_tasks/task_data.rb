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

      # Returns a list of sorted Task Data objects that represent the
      # available Tasks.
      #
      # Tasks are sorted by category, and within a category, by Task name.
      # Determining a Task's category require its latest Run record.
      # To optimize calls to the database, a single query is done to get the
      # last Run for each Task, and Task Data instances are initialized with
      # these last_run values.
      #
      # @return [Array<TaskData>] the list of Task Data.
      def available_tasks
        task_names = Task.available_tasks.map(&:name)
        available_task_runs = Run.where(task_name: task_names)
        last_runs = Run.where(
          id: available_task_runs.select("MAX(id) as id").group(:task_name)
        )

        task_names.map do |task_name|
          last_run = last_runs.find { |run| run.task_name == task_name }
          TaskData.new(task_name, last_run)
        end.sort_by!(&:name)
      end
    end

    # Initializes a Task Data with a name and optionally a last_run.
    #
    # @param name [String] the name of the Task subclass.
    # @param last_run [MaintenanceTasks::Run] optionally, a Run record to
    #   set for the Task.
    def initialize(name, last_run = :none_passed)
      @name = name
      @last_run = last_run unless last_run == :none_passed
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
      file = task.instance_method(:process).source_location.first
      File.read(file)
    end

    # Retrieves the latest Run associated with the Task.
    #
    # @return [MaintenanceTasks::Run] the Run record.
    # @return [nil] if there are no Runs associated with the Task.
    def last_run
      return @last_run if defined?(@last_run)
      @last_run = runs.first
    end

    # Returns the set of Run records associated with the Task previous to the
    # last Run. This collection represents a historic of past Runs for
    # information purposes, since the base for Task Data information comes
    # primarily from the last Run.
    #
    # @return [ActiveRecord::Relation<MaintenanceTasks::Run>] the relation of
    #   record previous to the last Run.
    def previous_runs
      return Run.none unless last_run
      runs.where.not(id: last_run.id)
    end

    # @return [Boolean] whether the Task has been deleted.
    def deleted?
      Task.named(name)
      false
    rescue Task::NotFoundError
      true
    end

    # The Task status. It returns the status of the last Run, if present. If the
    # Task does not have any Runs, the Task status is `new`.
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
      !deleted? && Task.named(name) < CsvCollection
    end

    # @return [Array<String>] the names of parameters the Task accepts.
    def parameter_names
      if deleted?
        []
      else
        Task.named(name).attribute_names
      end
    end

    private

    def runs
      Run.where(task_name: name).with_attached_csv.order(created_at: :desc)
    end
  end
end
