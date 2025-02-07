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
        "'sha256-z0htrLRVYM0doCiOj4SBCY7k1tegPO2ixHnnN1u+WDY='",
      )
      policy.script_src(
        # page refresh script
        "'sha256-ph0JAHGbHsnr8ZQBxstb/uf/D132k0DOqDll3fVPeKA='",
      )
      policy.frame_ancestors(:self)
    end

    protect_from_forgery with: :exception
  end
end
