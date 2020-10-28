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

    test '#format_ticks shows only the ticks if tick_total is not set' do
      run = Run.new(tick_count: 42)
      assert_equal '42', format_ticks(run)
    end

    test '#format_ticks shows only the ticks if tick_total is 0' do
      run = Run.new(tick_count: 0, tick_total: 0)
      assert_equal '0', format_ticks(run)
    end

    test '#format_ticks renders a <progress> element' do
      run = Run.new(tick_count: 42, tick_total: 84)
      render(inline: '<%= format_ticks(run) %>', locals: { run: run })
      assert_select 'progress[value=42][max=84]'
    end

    test '#progress_text shows the ticks, total and percentage' do
      run = Run.new(tick_count: 42, tick_total: 84)
      assert_equal '42 / 84 (50%)', progress_text(run)
    end

    test '#progress_text percentage rounds down to the nearest integer' do
      run = Run.new(tick_count: 999, tick_total: 1000)
      assert_equal '999 / 1000 (99%)', progress_text(run)
    end

    test '#status_tag renders a span with the appropriate tag based on status' do
      tag_classes = {
        'enqueued' => 'tag is-primary',
        'running' => 'tag is-info',
        'interrupted' => 'tag is-warning',
        'paused' => 'tag is-warning',
        'succeeded' => 'tag is-success',
        'cancelled' => 'tag is-dark',
        'errored' => 'tag is-danger',
      }

      tag_classes.each do |status, tag_class|
        expected_result = "<span class=\"#{tag_class}\">#{status}</span>"
        assert_equal expected_result, status_tag(status)
      end
    end
  end
end
