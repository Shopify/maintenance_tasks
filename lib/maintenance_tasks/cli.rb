# frozen_string_literal: true

require 'thor'

module MaintenanceTasks
  # Defines the command line interface commands exposed by Maintenance Tasks in
  # the executable file.
  class CLI < Thor
    class << self
      # Return a failed exit status in case of an error.
      def exit_on_failure?
        true
      end
    end

    desc 'perform [TASK NAME]', 'Runs the given Maintenance Task'

    long_desc <<-LONGDESC
      `maintenance_tasks perform` will run the Maintenance Task specified by the
      [TASK NAME] argument.

      Available Tasks:

      #{MaintenanceTasks::Task.available_tasks.join("\n\n")}
    LONGDESC

    # Command to run a Task.
    #
    # It instantiates a Runner and sends a run message with the given Task name.
    #
    # @param name [String] the name of the Task to be run.
    def perform(name)
      task = Runner.new.run(name: name)
      say_status(:success, "#{task.name} was enqueued.", :green)
    rescue => error
      say_status(:error, error.message, :red)
    end
  end
  private_constant :CLI
end
