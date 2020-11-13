# frozen_string_literal: true

module MaintenanceTasks
  # This class is responsible for running a given Task.
  class Runner
    class RunError < StandardError; end

    # Runs a Task.
    #
    # This method creates a Run record for the given Task name and enqueues the
    # Run.
    #
    # @param name [String] the name of the Task to be run.
    #
    # @raise [RunError] if validation errors occur while creating the Run.
    def run(name:)
      run = Run.new(task_name: name)
      unless run.enqueue
        raise RunError, run.errors.full_messages.join(' ')
      end
    end
  end
end
