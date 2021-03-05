# frozen_string_literal: true
module MaintenanceTasks
  # Module for common view helpers.
  #
  # @api private
  module ApplicationHelper
    # Renders pagination-related text showing the current page, total pages,
    # and total number of records, if there is more than one page present.
    # @param page [GearedPagination::Page] the page instance containing
    #   pagination details.
    # @param record_type [String] the type of the recordset.
    # @return [String] the HTML to render with the helpful pagination text.
    def pagination_text(page, record_type)
      page_count = page.recordset.page_count
      if page_count > 1
        record_count = page.recordset.records_count
        tag.span("Showing page #{page.number} of #{page_count} " \
        "(#{record_count} total #{record_type.pluralize(record_count)})")
      end
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
