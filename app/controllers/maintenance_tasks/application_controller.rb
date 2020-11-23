# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # @api private
  class ApplicationController < ActionController::Base
    include Pagy::Backend

    BULMA_CDN = 'https://cdn.jsdelivr.net'

    content_security_policy do |policy|
      policy.style_src(BULMA_CDN)
      policy.frame_ancestors(:self)
    end

    protect_from_forgery with: :exception
  end
  private_constant :ApplicationController
end
