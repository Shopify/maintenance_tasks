# frozen_string_literal: true
module MaintenanceTasks
  # Module for common view helpers.
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
  end
end
