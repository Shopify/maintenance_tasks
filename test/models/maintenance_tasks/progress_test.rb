# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class ProgressTest < ActiveSupport::TestCase
    setup do
      @run = Run.new(tick_total: 7, tick_count: 4, status: :running)
      @progress = Progress.new(@run)
    end

    test '#value is the Run tick count' do
      assert_equal 4, @progress.value
    end

    test '#value is nil if the Run does not have a tick total' do
      @run.tick_total = nil
      assert_nil @progress.value
    end

    test '#value is the Run tick count if the Run does not have a tick total and it is stopped' do
      @run.status = :paused
      @run.tick_total = nil

      assert_equal 4, @progress.value
    end

    test '#value is nil if the Run tick count is greater than its tick total' do
      @run.tick_count = 8

      assert_nil @progress.value
    end

    test '#max is the Run tick total' do
      assert_equal 7, @progress.max
    end

    test '#max is the Run tick count if the Run does not have a tick total' do
      @run.tick_total = nil
      assert_equal 4, @progress.max
    end

    test '#max is the Run tick count if the Run tick count is greater than its tick total' do
      @run.tick_count = 8
      assert_equal 8, @progress.max
    end

    test '#title returns a description with tick count, tick total, and percentage' do
      assert_equal 'Processed 4 out of 7 (57%)', @progress.title
    end

    test '#title returns a description with tick count when tick total is not present' do
      @run.tick_total = nil
      assert_equal 'Processed 4 items.', @progress.title
    end

    test '#title returns a description with tick count and tick total when tick count is greater than its tick total' do
      @run.tick_count = 8
      assert_equal 'Processed 8 items (expected 7).', @progress.title
    end

    test '#title pluralizes the description according to the tick count' do
      @run.tick_count = 1
      @run.tick_total = nil
      assert_equal 'Processed 1 item.', @progress.title
    end
  end
end
