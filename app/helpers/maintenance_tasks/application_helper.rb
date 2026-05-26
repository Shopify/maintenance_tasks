# frozen_string_literal: true

module MaintenanceTasks
  # Module for common view helpers.
  #
  # @api private
  module ApplicationHelper
    # Renders a time element with the given datetime, worded as relative to the
    # current time. The absolute UTC time is exposed via aria-label so that
    # assistive technologies (and touch users without hover) can read it,
    # not just desktop users hovering for the title tooltip.
    #
    # @param datetime [ActiveSupport::TimeWithZone] the time to be presented.
    # @return [String] the HTML to render with the relative datetime in words.
    def time_ago(datetime)
      time_tag(datetime, aria: { label: "#{datetime.utc.strftime("%B %-d, %Y at %H:%M")} UTC" }) do
        time_ago_in_words(datetime) + " ago"
      end
    end
  end
end
