# frozen_string_literal: true

module MaintenanceTasks
  # Helpers for formatting data in the maintenance_tasks views.
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
    # total and percentage.
    #
    # @param run [Run] the run for which the ticks are formatted.
    # @return [String] the progress information properly formatted.
    def format_ticks(run)
      if run.tick_total
        percentage = 100.0 * run.tick_count / run.tick_total
        "#{run.tick_count} / #{run.tick_total} "\
          "(#{number_to_percentage(percentage.floor, precision: 0)})"
      else
        run.tick_count.to_s
      end
    end
  end
end
