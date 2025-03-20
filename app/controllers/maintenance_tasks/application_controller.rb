# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    BULMA_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src(
        BULMA_CDN,
        # ruby syntax highlighting
        "'sha256-2AM66zjeDBmWDHyVQs45fGjYfGmjoZBwkyy5tNwIWG0='",
      )
      policy.script_src(
        # page refresh script
        "'sha256-q5UnlDKO/KeXUj/e2GI8aGSHDx1kF6kSefve1lCZuLw='",
      )
      policy.frame_ancestors(:self)
    end

    protect_from_forgery with: :exception
  end
end
