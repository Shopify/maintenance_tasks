# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < ActionController::Base
    JSDELIVR_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src(
        JSDELIVR_CDN,
        # https://github.com/hotwired/turbo/blob/201f8b3260bfbc15635d24c9961ff027747fb046/src/core/drive/progress_bar.ts#L66
        # https://github.com/hotwired/turbo/pull/501
        "'sha256-rql2tlBWA4Hb3HHbUfw797urk+ifBd6EAovoOUGt0oI='",
        # ruby highlight inline style in applcation.html.erb
        "'sha256-ZKMT34GDkdZirz8F7qMQsvFYVJqdYSQfNGCP1BX1VbY='",
      )
      policy.script_src(JSDELIVR_CDN)
      policy.frame_ancestors(:self)
    end

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
