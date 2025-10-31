# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    BULMA_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src(
        :self,
        BULMA_CDN,
      )
      policy.style_src_elem(
        BULMA_CDN,
        # <style> tag in app/views/layouts/maintenance_tasks/application.html.erb
        "'sha256-LVai3C2/+O9MPVaeiRrXbcSwDbPxqWfXI4pz487d9Js='",
      )
      capybara_lockstep_scripts = [
        "'sha256-1AoN3ZtJC5OvqkMgrYvhZjp4kI8QjJjO7TAyKYiDw+U='",
        "'sha256-QVSzZi6ZsX/cu4h+hIs1iVivG1BxUmJggiEsGDIXBG0='", # with debug on
      ] if defined?(Capybara::Lockstep)
      policy.script_src_elem(
        # <script> tag in app/views/layouts/maintenance_tasks/application.html.erb
        "'sha256-NiHKryHWudRC2IteTqmY9v1VkaDUA/5jhgXkMTkgo2w='",
        # <script> tag for capybara-lockstep
        *capybara_lockstep_scripts,
      )

      policy.require_trusted_types_for # disable because we use new DOMParser().parseFromString
      policy.frame_ancestors(:self)
      policy.connect_src(:self)
      policy.form_action(:self)
    end

    protect_from_forgery with: :exception
  end
end
