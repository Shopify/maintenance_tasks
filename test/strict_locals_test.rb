# frozen_string_literal: true

require "test_helper"

class StrictLocalsTest < ActiveSupport::TestCase
  test "all engine templates declare strict locals" do
    view_path = MaintenanceTasks::Engine.root.join("app/views")
    lookup_context = ActionView::LookupContext.new([view_path.to_s])

    Dir.glob("**/*.erb", base: view_path).sort.each do |file|
      basename = File.basename(file)
      prefix = File.dirname(file)
      prefix = "" if prefix == "."
      name = basename.delete_prefix("_").split(".").first
      partial = basename.start_with?("_")

      templates = lookup_context.find_all(name, [prefix], partial)
      assert_equal(1, templates.size, "Expected #{file} to resolve to a single template")
      assert_predicate(
        templates.first,
        :strict_locals?,
        "#{file} must declare the locals it accepts with a `<%# locals: (...) %>` magic comment on its first line",
      )
    end
  end
end
