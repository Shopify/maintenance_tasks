# frozen_string_literal: true

module MaintenanceTasks
  # This class is responsible for running a given Task.
  module Runner
    extend self

    # Exception raised when a Task Job couldn't be enqueued.
    class EnqueuingError < StandardError
      # Initializes a Enqueuing Error.
      #
      # @param run [Run] the Run which failed to be enqueued.
      # @return [EnqueuingError] an Enqueuing Error instance.
      def initialize(run)
        super("The job to perform #{run.task_name} could not be enqueued")
        @run = run
      end

      attr_reader :run
    end

    # Runs a Task.
    #
    # This method creates a Run record for the given Task name and enqueues the
    # Run.
    #
    # @param name [String] the name of the Task to be run.
    #
    # @return [Task] the Task that was run.
    #
    # @raise [EnqueuingError] if an error occurs while enqueuing the Run.
    # @raise [ActiveRecord::RecordInvalid] if validation errors occur while
    #   creating the Run.
    def run(name:)
      run = Run.active.find_by(task_name: name) || Run.new(task_name: name)

      run.enqueued!
      enqueue(run)
      Task.named(name)
    end

    private

    def enqueue(run)
      unless MaintenanceTasks.job.constantize.perform_later(run)
        raise "The job to perform #{run.task_name} could not be enqueued. "\
          'Enqueuing has been prevented by a callback.'
      end
    rescue => error
      run.persist_error(error)
      raise EnqueuingError, run
    end
  end
end
