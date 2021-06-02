# frozen_string_literal: true
# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  policy.base_uri(:none)
  policy.default_src(:self)
  policy.object_src(:none)
  policy.script_src(:self, :strict_dynamic)
  policy.frame_ancestors(:none)

  policy.block_all_mixed_content

  # Specify URI for violation reports
  # policy.report_uri "/csp-violation-report-endpoint"
end

# Remove this header since Chrome warns
Rails.application.config.action_dispatch.default_headers
  .delete("X-Frame-Options")

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
