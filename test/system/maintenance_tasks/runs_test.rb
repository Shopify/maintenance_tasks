# frozen_string_literal: true

require 'application_system_test_case'

module MaintenanceTasks
  class RunsTest < ApplicationSystemTestCase
    setup { freeze_time }

    test 'run a task' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'
      assert_text 'Task Maintenance::UpdatePostsTask enqueued.'
      assert_table with_rows: [[I18n.l(Time.now.utc)]]
      assert_no_button 'Run'
    end

    test 'pause a Run' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'

      click_on 'Pause'

      assert_table with_rows: [[I18n.l(Time.now.utc), 'paused']]
    end

    test 'resume a Run' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'

      click_on 'Pause'

      with_queue_adapter(:test) do
        click_on 'Resume'
      end

      assert_table with_rows: [[I18n.l(Time.now.utc), 'enqueued']]
    end

    test 'cancel a Run' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'

      click_on 'Cancel'

      assert_table with_rows: [[I18n.l(Time.now.utc), 'cancelled']]
    end

    test 'run a task that errors' do
      visit maintenance_tasks_path

      click_on 'Maintenance::ErrorTask'

      with_queue_adapter(:inline) do
        click_on 'Run'
      end

      assert_text 'Task Maintenance::ErrorTask enqueued.'

      assert_table with_rows: [
        [
          I18n.l(Time.now.utc),
          'errored',
          'ArgumentError',
          'Something went wrong',
          "app/tasks/maintenance/error_task.rb:9:in `task_iteration'",
        ],
      ]
    end

    private

    def with_queue_adapter(adapter)
      original_adapter = TaskJob.queue_adapter
      TaskJob.queue_adapter = adapter
      yield
    ensure
      TaskJob.queue_adapter = original_adapter
    end
  end
end
