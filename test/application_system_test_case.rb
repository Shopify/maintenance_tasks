# frozen_string_literal: true

require "test_helper"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

Capybara.save_path = Rails.root.join("tmp/downloads").to_s

module PageLogs
  def initialize(...)
    super
    on("console", ->(console_message) {
      # FIXME: we can't raise or warn because we're in a thread, and the test runner hangs if the thread dies
      puts "Console message: #{console_message.text}"
    })
  end
end
Playwright::Page.prepend(PageLogs)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :playwright # TODO: handle console messages

  setup do
    travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
  end

  teardown do
    FileUtils.rm_rf(Capybara.save_path)
  end
end
