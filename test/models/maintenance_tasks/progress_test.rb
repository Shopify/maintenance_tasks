# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class ProgressTest < ActiveSupport::TestCase
    setup do
      @run = Run.new(tick_total: 7000, tick_count: 4000, status: :running)
      @progress = Progress.new(@run)
    end

    test "#value is the Run tick count" do
      assert_equal 4000, @progress.value
    end

    test "#value is nil if the Run does not have a tick total" do
      @run.tick_total = nil
      assert_nil @progress.value
    end

    test "#value is the Run tick count if the Run does not have a tick total and it is stopped" do
      @run.status = :paused
      @run.tick_total = nil

      assert_equal 4000, @progress.value
    end

    test "#value is nil if the Run tick count is strictly greater than its tick total" do
      @run.tick_count = 7000
      refute_nil @progress.value

      @run.tick_count = 8000
      assert_nil @progress.value
    end

    test "#max is the Run tick total" do
      assert_equal 7000, @progress.max
    end

    test "#max is the Run tick count if the Run does not have a tick total" do
      @run.tick_total = nil
      assert_equal 4000, @progress.max
    end

    test "#max is the Run tick count if the Run tick count is greater than its tick total" do
      @run.tick_count = 8000
      assert_equal 8000, @progress.max
    end

    test "#text returns a description with tick count, tick total, and percentage" do
      assert_equal "Processed 4,000 out of 7,000 items (57%).", @progress.text
    end

    test "#text returns a description with tick count when tick total is not present" do
      @run.tick_total = nil
      assert_equal "Processed 4,000 items.", @progress.text
    end

    test "#text returns a description with tick count and tick total when tick count is greater than its tick total" do
      @run.tick_count = 8000
      assert_equal "Processed 8,000 items (expected 7,000).", @progress.text
    end

    test "#text pluralizes the description according to the tick count" do
      @run.tick_count = 1
      @run.tick_total = nil
      assert_equal "Processed 1 item.", @progress.text
    end
  end
end
