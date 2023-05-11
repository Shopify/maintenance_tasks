# frozen_string_literal: true

require "test_helper"
require "yard"

class DocumentationTest < ActiveSupport::TestCase
  DOC_WARNING_ALLOWLIST = [
    /Undocumentable superclass.*class ApplicationController/m,
  ]

  test "documentation is correctly written" do
    output = %x(bundle exec yard --no-save --no-output --no-stats)
    warnings = output.scan(/\[warn\]: .*\n\n/m).reject { |warning| warning_ignored?(warning) }
    assert_empty warnings
  end

  private

  def warning_ignored?(warning)
    DOC_WARNING_ALLOWLIST.any? do |matcher|
      warning.match?(matcher)
    end
  end
end
