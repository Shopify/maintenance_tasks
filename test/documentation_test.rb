# frozen_string_literal: true

require "active_support"
require "active_support/test_case"
require "yard"

class DocumentationTest < ActiveSupport::TestCase
  test "documentation is correctly written" do
    assert_empty %x(bundle exec yard --no-save --no-output --no-stats)
  end
end
