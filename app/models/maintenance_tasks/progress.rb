# frozen_string_literal: true

module MaintenanceTasks
  # This class generates progress information about a Run.
  class Progress
    include ActiveSupport::NumberHelper
    include ActionView::Helpers::TextHelper

    # Sets the Progress initial state with a Run.
    #
    # @param run [Run] the source of progress information.
    def initialize(run)
      @run = run
    end

    # Defines the value of progress information. This represents the amount that
    # is already done out of the progress maximum.
    #
    # For indefinite-style progress information, value is nil. That highlights
    # that a Run is in progress but it is not possible to estimate how close to
    # completion it is.
    #
    # When a Run is stopped, the value is present even if there is no total.
    # That represents a progress information that assumes that the current value
    # is also equal to is max, showing a progress as completed.
    #
    # @return [Integer] if progress can be determined or the Run is stopped.
    # @return [nil] if progress can't be determined and the Run isn't stopped.
    def value
      @run.tick_count if estimatable? || @run.stopped?
    end

    # The maximum amount of work expected to be done. This is extracted from the
    # Run's tick total attribute when present, or it is equal to the Run's
    # tick count.
    #
    # This amount is enqual to the Run's tick count if the tick count is greater
    # than the tick total. This represents that the total was underestimated.
    #
    # @return [Integer] the progress maximum amount.
    def max
      estimatable? ? @run.tick_total : @run.tick_count
    end

    # The text containing progress information. This describes the progress of
    # the Run so far. It includes the percentage done out of the maximum, if an
    # estimate is possible.
    #
    # @return [String] the text for the Run progress.
    def text
      count = @run.tick_count
      total = @run.tick_total

      if !total?
        "Processed #{number_to_delimited(count)} "\
          "#{"item".pluralize(count)}."
      elsif over_total?
        "Processed #{number_to_delimited(count)} "\
          "#{"item".pluralize(count)} "\
          "(expected #{number_to_delimited(total)})."
      else
        percentage = 100.0 * count / total

        "Processed #{number_to_delimited(count)} out of "\
          "#{number_to_delimited(total)} #{"item".pluralize(total)} "\
          "(#{number_to_percentage(percentage, precision: 0)})."
      end
    end

    private

    def total?
      @run.tick_total.to_i > 0
    end

    def estimatable?
      total? && !over_total?
    end

    def over_total?
      @run.tick_count > @run.tick_total
    end
  end
end
