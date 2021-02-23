# frozen_string_literal: true
module MaintenanceTasks
  # Module for common view helpers.
  #
  # @api private
  module ApplicationHelper
    include Pagy::Frontend

    # Renders pagination for the page, if there is more than one page present.
    #
    # @param pagy [Pagy] the pagy instance containing pagination details,
    #   including the number of pages the results are spread across.
    # @return [String] the HTML to render for pagination.
    def pagination(pagy)
      raw(pagy_bulma_nav(pagy)) if pagy.pages > 1
    end

    # Renders a time element with the given datetime, worded as relative to the
    # current time.
    #
    # The ISO 8601 version of the datetime is shown on hover
    # via a title attribute.
    #
    # @param datetime [ActiveSupport::TimeWithZone] the time to be presented.
    # @return [String] the HTML to render with the relative datetime in words.
    def time_ago(datetime)
      time_tag(datetime, title: datetime.utc.iso8601, class: 'is-clickable') do
        time_ago_in_words(datetime) + ' ago'
      end
    end
  end
end
