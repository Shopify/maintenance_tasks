# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    BULMA_CDN = "https://cdn.jsdelivr.net"

    RUBY_SYNTAX_HIGHLIGHTING = "'sha256-2AM66zjeDBmWDHyVQs45fGjYfGmjoZBwkyy5tNwIWG0='"
    PAGE_REFRESH_SCRIPT = "'sha256-NiHKryHWudRC2IteTqmY9v1VkaDUA/5jhgXkMTkgo2w='"

    content_security_policy do |policy|
      policy.style_src_elem(BULMA_CDN, RUBY_SYNTAX_HIGHLIGHTING)
      policy.script_src_elem(PAGE_REFRESH_SCRIPT)

      policy.frame_ancestors(:self)
      policy.connect_src(:self)
      policy.form_action(:self)
    end

    protect_from_forgery with: :exception
  end
end
