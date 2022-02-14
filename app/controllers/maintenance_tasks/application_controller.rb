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
        # https://cdn.jsdelivr.net/npm/@hotwired/turbo@7.1.0/dist/turbo.es2017-umd.js
        # line 1188
        "'sha256-rql2tlBWA4Hb3HHbUfw797urk+ifBd6EAovoOUGt0oI='",
        # https://cdn.jsdelivr.net/npm/@hotwired/turbo@7.1.0/dist/turbo.es2017-umd.js
        # line 334
        "'sha256-y9V0na/WU44EUNI/HDP7kZ7mfEci4PAOIjYOOan6JMA='",
        # https://cdn.jsdelivr.net/npm/@hotwired/turbo@7.1.0/dist/turbo.es2017-umd.js
        # line 334
        "'sha256-VELoZazE4c2GJUpn8GbzkTIBqEEuvRmGtUwrKI578Ak='",
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
