# frozen_string_literal: true

module MaintenanceTasks
  # Helpers for formatting data in the maintenance_tasks views.
  #
  # @api private
  module TaskHelper
    STATUS_COLOURS = {
      'enqueued' => ['is-primary is-light'],
      'running' => ['is-info'],
      'interrupted' => ['is-info', 'is-light'],
      'pausing' => ['is-warning', 'is-light'],
      'paused' => ['is-warning'],
      'succeeded' => ['is-success'],
      'cancelling' => ['is-light'],
      'cancelled' => ['is-dark'],
      'errored' => ['is-danger'],
    }

    # Formats a run backtrace.
    #
    # @param backtrace [Array<String>] the backtrace associated with an
    #   exception on a Task that ran and raised.
    # @return [String] the parsed, HTML formatted version of the backtrace.
    def format_backtrace(backtrace)
      safe_join(backtrace.to_a, tag.br)
    end

    # Renders the progress bar.
    #
    # The style of the progress tag depends on the Run status. It also renders
    # an infinite progress when a Run is active but there is no total
    # information to estimate completion.
    #
    # @param run [Run] the Run which the progress bar will be based on.
    #
    # @return [String] the progress information properly formatted.
    # @return [nil] if the run has not started yet.
    def progress(run)
      return unless run.started?

      progress = Progress.new(run)

      tag.progress(
        value: progress.value,
        max: progress.max,
        title: progress.title,
        class: ['progress'] + STATUS_COLOURS.fetch(run.status)
      )
    end

    # Renders a span with a Run's status, with the corresponding tag class
    # attached.
    #
    # @param status [String] the status for the Run.
    # @return [String] the span element containing the status, with the
    #   appropriate tag class attached.
    def status_tag(status)
      tag.span(status.capitalize, class: ['tag'] + STATUS_COLOURS.fetch(status))
    end

    # Returns the distance between now and the Run's expected completion time,
    # if the Run has an estimated_completion_time.
    #
    # @param run [MaintenanceTasks::Run] the Run for which the estimated time to
    #   completion is being calculated.
    # return [String, nil] the distance in words, or nil if the Run has no
    #   estimated completion time.
    def estimated_time_to_completion(run)
      estimated_completion_time = run.estimated_completion_time
      if estimated_completion_time.present?
        time_ago_in_words(estimated_completion_time)
      end
    end

    # Reports the approximate elapsed time a Run has been processed so far based
    # on the Run's time running attribute.
    #
    # @param run [Run] the source of the time to be reported.
    #
    # @return [String] the description of the time running attribute.
    def time_running_in_words(run)
      distance_of_time_in_words(0, run.time_running, include_seconds: true)
    end

    # Returns the list of Task classes, sorted in the following order:
    #
    #   * Active tasks (tasks where the last run is active)
    #   * New tasks
    #   * Old tasks (tasks where the last run is completed)
    #
    # @param tasks [Array<Class>] the list of Task classes to sort.
    # @return [Array<Class>] the sorted list of Task classes.
    def sorted_tasks(tasks)
      tasks.sort_by do |task|
        last_run = task.last_run

        if last_run.present? && last_run.active?
          0
        elsif last_run.nil?
          1
        else
          2
        end
      end
    end
  end
  private_constant :TaskHelper
end
