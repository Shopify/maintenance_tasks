# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TickerTest < ActiveSupport::TestCase
    setup { freeze_time }

    test "#ticks persists if enough time has passed" do
      ticker = Ticker.new(0) do |ticks, duration|
        @ticks = ticks
        @duration = duration
      end

      ticker.tick
      assert_equal 1, @ticks
      assert_equal 0, @duration
    end

    test "#tick doesn't persist immediately if not enough time has passed" do
      @called = false
      ticker = Ticker.new(1.second) { |_ticks| @called = true }
      ticker.tick
      refute @called
    end

    test "#tick persists if the tick happens after the duration has passed" do
      ticker = Ticker.new(1.second) do |ticks, duration|
        @ticks = ticks
        @duration = duration
      end
      travel 2.seconds
      ticker.tick
      assert_equal 1, @ticks
      assert_equal 2, @duration
    end

    test "#tick persists multiple ticks after the duration has passed" do
      ticker = Ticker.new(1.second) do |ticks, duration|
        @ticks = ticks
        @duration = duration
      end
      ticker.tick
      travel 2.seconds
      ticker.tick
      assert_equal 2, @ticks
      assert_equal 2, @duration
    end

    test "#persist doesn't persist if no tick happened" do
      @called = false
      ticker = Ticker.new(0) { |_ticks| @called = true }
      ticker.persist
      refute @called
    end

    test "#tick doesn't persist if ticks were already persisted" do
      @times_called = 0
      ticker = Ticker.new(0) { |_ticks| @times_called += 1 }
      ticker.tick
      2.times { ticker.persist }
      assert_equal 1, @times_called
    end
  end
end
