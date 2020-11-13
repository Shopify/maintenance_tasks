# frozen_string_literal: true

module MaintenanceTasks
  # Helpers for formatting data in the maintenance_tasks views.
  #
  # @api private
  module TaskHelper
    # Formats a run backtrace.
    #
    # @param backtrace [Array<String>] the backtrace associated with an
    #   exception on a Task that ran and raised.
    # @return [String] the parsed, HTML formatted version of the backtrace.
    def format_backtrace(backtrace)
      safe_join(backtrace.to_a, tag.br)
    end

    # Formats the ticks.
    #
    # Only shows the ticks or if the total is available, shows the ticks,
    # total and percentage. Does not show ticks if run has not started.
    #
    # @param run [Run] the run for which the ticks are formatted.
    # @return [String, nil] the progress information properly formatted, or
    #   nil if the run has not started yet.
    def format_ticks(run)
      return unless run.started?

      if run.tick_total.to_i > 0
        safe_join([
          tag.progress(value: run.tick_count, max: run.tick_total,
            class: 'progress is-small'),
          progress_text(run),
        ], ' ')
      else
        run.tick_count.to_s
      end
    end

    # Renders a span with a Run's status, with the corresponding tag class
    # attached.
    #
    # @param status [String] the status for the Run.
    # @return [String] the span element containing the status, with the
    #   appropriate tag class attached.
    def status_tag(status)
      tag_labels = {
        'enqueued' => 'primary',
        'running' => 'info',
        'interrupted' => 'warning',
        'paused' => 'warning',
        'succeeded' => 'success',
        'cancelled' => 'dark',
        'errored' => 'danger',
      }

      tag.span(status, class: "tag is-#{tag_labels.fetch(status)}")
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

    private

    def progress_text(run)
      percentage = 100.0 * run.tick_count / run.tick_total
      "#{run.tick_count} / #{run.tick_total} "\
        "(#{number_to_percentage(percentage.floor, precision: 0)})"
    end
  end
  private_constant :TaskHelper
end
