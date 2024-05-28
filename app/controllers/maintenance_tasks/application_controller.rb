# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < MaintenanceTasks.parent_controller.constantize
    content_security_policy do |policy|
      policy.style_src("'self'")
      policy.script_src("'self'")
      policy.frame_ancestors(:self)
    end

    protect_from_forgery with: :exception
  end
end
