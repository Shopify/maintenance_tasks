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
    # Run. If a CSV file is provided, it is attached to the Run record.
    #
    # @param name [String] the name of the Task to be run.
    # @param csv_file [attachable, nil] a CSV file that provides the collection
    #   for the Task to iterate over when running, in the form of an attachable
    #   (see https://edgeapi.rubyonrails.org/classes/ActiveStorage/Attached/One.html#method-i-attach).
    #   Value is nil if the Task does not use CSV iteration.
    # @param arguments [Hash] the arguments to persist to the Run and to make
    #   accessible to the Task.
    #
    # @return [Task] the Task that was run.
    #
    # @raise [EnqueuingError] if an error occurs while enqueuing the Run.
    # @raise [ActiveRecord::RecordInvalid] if validation errors occur while
    #   creating the Run.
    # @raise [ActiveRecord::ValueTooLong] if the creation of the Run fails due
    #   to a value being too long for the column type.
    def run(name:, csv_file: nil, arguments: {}, run_model: Run)
      run = run_model.new(task_name: name, arguments: arguments)
      if csv_file
        run.csv_file.attach(csv_file)
        run.csv_file.filename = filename(name)
      end
      job = instantiate_job(run)
      run.job_id = job.job_id
      yield run if block_given?
      run.enqueued!
      enqueue(run, job)
      Task.named(name)
    end

    # Resumes a Task.
    #
    # This method re-instantiates and re-enqueues a job for a Run that was
    # previously paused.
    #
    # @param run [MaintenanceTasks::Run] the Run record to be resumed.
    #
    # @return [TaskJob] the enqueued Task job.
    #
    # @raise [EnqueuingError] if an error occurs while enqueuing the Run.
    def resume(run)
      job = instantiate_job(run)
      run.job_id = job.job_id
      run.enqueued!
      enqueue(run, job)
    end

    private

    def enqueue(run, job)
      unless job.enqueue
        raise "The job to perform #{run.task_name} could not be enqueued. "\
          "Enqueuing has been prevented by a callback."
      end
    rescue => error
      run.persist_error(error)
      raise EnqueuingError, run
    end

    def filename(task_name)
      formatted_task_name = task_name.underscore.gsub("/", "_")
      "#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}_#{formatted_task_name}.csv"
    end

    def instantiate_job(run)
      MaintenanceTasks.job.constantize.new(run)
    end
  end
end
