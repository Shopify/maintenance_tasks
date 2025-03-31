# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    BULMA_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src_elem(
        BULMA_CDN,
        # <style> tag in app/views/layouts/maintenance_tasks/application.html.erb
        "'sha256-2AM66zjeDBmWDHyVQs45fGjYfGmjoZBwkyy5tNwIWG0='",
      )
      policy.script_src_elem(
        # <script> tag in app/views/layouts/maintenance_tasks/application.html.erb
        "'sha256-NiHKryHWudRC2IteTqmY9v1VkaDUA/5jhgXkMTkgo2w='",
      )

      policy.require_trusted_types_for # disable because we use new DOMParser().parseFromString
      policy.frame_ancestors(:self)
      policy.connect_src(:self)
      policy.form_action(:self)
    end

    protect_from_forgery with: :exception
  end
end
