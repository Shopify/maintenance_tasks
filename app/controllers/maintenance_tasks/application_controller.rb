# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < ActionController::Base
    JSDELIVR_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src(JSDELIVR_CDN)
      policy.script_src(JSDELIVR_CDN)
      policy.frame_ancestors(:self)
    end

    # cant get turbo to not output a csp error
    # although turbo will work just fine even with this error
    content_security_policy false if Rails.env == "test"

    before_action do
      request.content_security_policy_nonce_generator ||=
        ->(_request) { SecureRandom.base64(16) }
      request.content_security_policy_nonce_directives = [
        "style-src",
      ]
    end

    protect_from_forgery with: :exception
  end
end
