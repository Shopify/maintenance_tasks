# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  # Setting all options available in ActionDispatch::ContentSecurityPolicy::DIRECTIVES to none
  policy.base_uri(:none)
  policy.child_src(:none)
  policy.connect_src(:none)
  policy.default_src(:none)
  policy.font_src(:none)
  policy.form_action(:none)
  policy.frame_ancestors(:none)
  policy.frame_src(:none)
  policy.img_src(:none)
  policy.manifest_src(:none)
  policy.media_src(:none)
  policy.object_src(:none)
  # policy.prefetch_src(:none) # Unsupported in Selenium
  # policy.require_trusted_types_for(:none) # Unsupported in Selenium
  policy.script_src(:none)
  policy.script_src_attr(:none)
  policy.script_src_elem(:none)
  policy.style_src(:none)
  policy.style_src_attr(:none)
  policy.style_src_elem(:none)
  policy.trusted_types(:none)
  policy.worker_src(:none)

  # Required configuration for iframing maintenance-tasks
  policy.style_src_elem(:self)
  policy.frame_src(:self)

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
