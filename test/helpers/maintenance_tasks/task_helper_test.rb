# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class TaskHelperTest < ActionView::TestCase
    setup do
      @run = Run.new
    end

    test '#format_backtrace converts the backtrace to a formatted string' do
      backtrace = [
        "app/jobs/maintenance/error_task.rb:13:in `foo'",
        "app/jobs/maintenance/error_task.rb:9:in `process'",
      ]

      expected_trace = 'app/jobs/maintenance/error_task.rb:13:in `foo&#39;' \
        '<br>app/jobs/maintenance/error_task.rb:9:in `process&#39;'

      assert_equal expected_trace, format_backtrace(backtrace)
    end

    test '#progress renders a <progress> when Run has started' do
      @run.started_at = Time.now

      Progress.expects(:new).with(@run).returns(
        mock(value: 42, max: 84, title: 'Almost there!')
      )

      expected = '<progress value="42" max="84" title="Almost there!" '\
        'class="progress is-primary is-light"></progress>'
      assert_equal expected, progress(@run)
    end

    test '#progress is nil if the Run has not started' do
      assert_nil progress(@run)
    end

    test '#progress returns a <progress> with no value when the Progress value is nil' do
      @run.started_at = Time.now
      Progress.expects(:new).with(@run).returns(
        mock(value: nil, max: 84, title: 'Almost there!')
      )
      expected = '<progress max="84" title="Almost there!" '\
        'class="progress is-primary is-light"></progress>'
      assert_equal expected, progress(@run)
    end

    test '#status_tag renders a span with the appropriate tag based on status' do
      expected = '<span class="tag is-warning is-light">Pausing</span>'
      assert_equal expected, status_tag('pausing')
    end

    test "#estimated_time_to_completion returns the Run's estimated_completion_time in words" do
      @run.expects(estimated_completion_time: Time.now + 2.minutes)
      assert_equal '2 minutes', estimated_time_to_completion(@run)
    end

    test '#estimated_time_to_completion returns nil if the Run has no estimated_completion_time' do
      assert_nil estimated_time_to_completion(@run)
    end

    test '#time_running_in_words reports the approximate time running of the given Run' do
      @run.time_running = 182.5
      assert_equal '3 minutes', time_running_in_words(@run)
    end

    test '#sorted_tasks orders list of tasks by active, new, then old' do
      Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      Run.create!(
        task_name: 'Maintenance::ErrorTask',
        status: :errored,
        started_at: Time.now,
        ended_at: Time.now,
      )

      old_task = TaskData.new('Maintenance::ErrorTask')
      new_task = TaskData.new('Maintenance::SomeNewTask')
      active_task = TaskData.new('Maintenance::UpdatePostsTask')

      available_tasks = [old_task, new_task, active_task]
      expected = [active_task, new_task, old_task]

      assert_equal(expected, sorted_tasks(available_tasks))
    end

    test '#highlight_code returns a HTML safe string' do
      assert_predicate highlight_code('self'), :html_safe?
    end

    test '#highlight_code wraps syntax in span' do
      assert_equal '<span class="ruby-kw">self</span>', highlight_code('self')
      assert_equal '<span class="ruby-const">CSV</span>', highlight_code('CSV')
      assert_equal '<span class="ruby-int">42</span>', highlight_code('42')
      assert_equal '<span class="ruby-float">4.2</span>', highlight_code('4.2')
      assert_equal '<span class="ruby-ivar">@foo</span>', highlight_code('@foo')
    end

    test '#highlight_code does not wrap whitespace' do
      assert_equal '<span class="ruby-int">1</span>' + "\n"\
        '<span class="ruby-int">2</span>', highlight_code("1\n2")
      assert_equal '<span class="ruby-int">1</span>' + ' '\
        '<span class="ruby-int">2</span>', highlight_code('1 2')
      assert_equal "\n", highlight_code("\n")
    end
  end
end
