# frozen_string_literal: true

require "active_support"
require "active_support/test_case"
require "yard"

class DocumentationTest < ActiveSupport::TestCase
  DOC_WARNING_ALLOWLIST = [
    "Undocumentable superclass",
  ]

  test "documentation is correctly written" do
    output = %x(bundle exec yard --no-save --no-output --no-stats)
    warnings = output.scan(/\[warn\]: .*/).reject { |warning| warning_ignored?(warning) }
    assert_empty warnings
  end

  private

  def warning_ignored?(warning)
    DOC_WARNING_ALLOWLIST.any? do |matcher|
      warning.match?(matcher)
    end
  end
end
