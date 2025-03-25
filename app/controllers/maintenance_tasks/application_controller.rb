# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    BULMA_CDN = "https://cdn.jsdelivr.net"

    ruby_syntax_highlighting_checksum = "'sha256-2AM66zjeDBmWDHyVQs45fGjYfGmjoZBwkyy5tNwIWG0='"
    page_refresh_script_checksum = "'sha256-2AM66zjeDBmWDHyVQs45fGjYfGmjoZBwkyy5tNwIWG0='"
    content_security_policy do |policy|
      policy.style_src(
        BULMA_CDN,
        ruby_syntax_highlighting_checksum,
      )
      policy.script_src(page_refresh_script_checksum)
      policy.script_src_elem(page_refresh_script_checksum)
      policy.frame_ancestors(:self)
    end

    protect_from_forgery with: :exception
  end
end
