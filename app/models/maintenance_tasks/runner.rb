# frozen_string_literal: true

module MaintenanceTasks
  # This class is responsible for running a given Task.
  class Runner
    # Runs a Task.
    #
    # This method creates a Run record for the given Task name and enqueues the
    # Run.
    #
    # @param name [String] the name of the Task to be run.
    #
    # @return [Task] the Task that was run.
    #
    # @raise [ActiveRecord::RecordInvalid] if validation errors occur while
    #   creating the Run.
    def run(name:)
      run = Run.active.find_by(task_name: name) || Run.create!(task_name: name)

      run.enqueued!
      MaintenanceTasks.job.perform_later(run)
      Task.named(name)
    end
  end
end
