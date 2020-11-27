# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class TaskHelperTest < ActionView::TestCase
    test '#format_backtrace converts the backtrace to a formatted string' do
      backtrace = [
        "app/jobs/maintenance/error_task.rb:13:in `foo'",
        "app/jobs/maintenance/error_task.rb:9:in `process'",
      ]

      expected_trace = 'app/jobs/maintenance/error_task.rb:13:in `foo&#39;' \
        '<br>app/jobs/maintenance/error_task.rb:9:in `process&#39;'

      assert_equal expected_trace, format_backtrace(backtrace)
    end

    test '#progress renders a <progress> with value and progress information title' do
      run = Run.new(tick_count: 42, tick_total: 84, started_at: Time.now)
      expected = '<progress value="42" max="84" title="Processed 42 out '\
        'of 84 (50%)" class="progress is-primary is-light"></progress>'
      assert_equal expected, progress(run)
    end

    test '#progress returns a <progress> with no value when tick_total is not set' do
      run = Run.new(tick_count: 42, started_at: Time.now)
      expected = '<progress max="42" title="Processed 42 items." '\
        'class="progress is-primary is-light"></progress>'
      assert_equal expected, progress(run)
    end

    test '#progress returns a <progress> with value when tick_total is not set and Run has completed' do
      run = Run.new(tick_count: 42, started_at: Time.now, status: :succeeded)
      expected = '<progress value="42" max="42" title="Processed 42 items." '\
        'class="progress is-success"></progress>'
      assert_equal expected, progress(run)
    end

    test '#progress returns a <progress> with no value when tick_total is 0' do
      run = Run.new(tick_count: 0, tick_total: 0, started_at: Time.now)
      expected = '<progress max="0" title="Processed 0 items." '\
        'class="progress is-primary is-light"></progress>'
      assert_equal expected, progress(run)
    end

    test '#progress returns nil if the Run has not started' do
      run = Run.new(tick_count: 0, tick_total: 10)
      assert_nil progress(run)
    end

    test '#status_tag renders a span with the appropriate tag based on status' do
      expected = '<span class="tag is-warning is-light">Pausing</span>'
      assert_equal expected, status_tag('pausing')
    end

    test "#estimated_time_to_completion returns the Run's estimated_completion_time in words" do
      run = Run.new
      run.stubs(estimated_completion_time: Time.now + 2.minutes)
      assert_equal '2 minutes', estimated_time_to_completion(run)
    end

    test '#estimated_time_to_completion returns nil if the Run has no estimated_completion_time' do
      run = Run.new
      assert_nil estimated_time_to_completion(run)
    end

    test '#time_running_in_words reports the approximate time running of the given Run' do
      run = Run.new(time_running: 182.5)
      assert_equal '3 minutes', time_running_in_words(run)
    end
  end
end
