# frozen_string_literal: true

require "stringio"
require "thor"

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

    desc "perform [TASK NAME]", "Runs the given Maintenance Task"

    long_desc <<-LONGDESC
      `maintenance_tasks perform` will run the Maintenance Task specified by the
      [TASK NAME] argument.

      Available Tasks:

      #{MaintenanceTasks::Task.available_tasks.join("\n\n")}
    LONGDESC

    # Specify the CSV file to process for CSV Tasks
    desc = "Supply a CSV file to be processed by a CSV Task, "\
      "--csv path/to/csv/file.csv"
    option :csv, lazy_default: :stdin, desc: desc
    # Specify arguments to supply to a Task supporting parameters
    desc = "Supply arguments for a Task that accepts parameters as a set of "\
      "<key>:<value> pairs."
    option :arguments, type: :hash, desc: desc

    # Command to run a Task.
    #
    # It instantiates a Runner and sends a run message with the given Task name.
    # If a CSV file is supplied using the --csv option, an attachable with the
    # File IO object is sent along with the Task name to run. If arguments are
    # supplied using the --arguments option, these are also passed to run.
    #
    # @param name [String] the name of the Task to be run.
    def perform(name)
      arguments = options[:arguments] || {}
      task = Runner.run(name: name, csv_file: csv_file, arguments: arguments)
      say_status(:success, "#{task.name} was enqueued.", :green)
    rescue => error
      say_status(:error, error.message, :red)
    end

    private

    def csv_file
      return unless options.key?(:csv)

      csv_option = options[:csv]

      if csv_option == :stdin
        {
          io: StringIO.new($stdin.read),
          filename: "stdin.csv",
          content_type: "text/csv",
        }
      else
        {
          io: File.open(csv_option),
          filename: File.basename(csv_option),
          content_type: "text/csv",
        }
      end
    rescue Errno::ENOENT
      raise ArgumentError, "CSV file not found: #{csv_option}"
    end
  end
end
