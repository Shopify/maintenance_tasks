# frozen_string_literal: true

require 'application_system_test_case'

class TasksTest < ApplicationSystemTestCase
  setup { freeze_time }

  test 'list all tasks' do
    visit maintenance_tasks_path

    assert_title 'Maintenance Tasks'

    assert_table 'Enqueue Task', with_rows: [
      ['Maintenance::UpdatePostsTask', ''],
      ['Maintenance::ErrorTask', ''],
    ]
  end

  test 'run a task' do
    visit maintenance_tasks_path

    within 'tr', text: 'Maintenance::UpdatePostsTask' do
      click_on 'Run'
    end

    assert_title 'Maintenance Tasks'

    assert_text 'Task Maintenance::UpdatePostsTask enqueued.'

    assert_no_table 'Enqueue Task', with_rows: [
      ['Maintenance::UpdatePostsTask', ''],
    ]

    assert_table 'Maintenance Task Runs', with_rows: [
      ['Maintenance::UpdatePostsTask', I18n.l(Time.now.utc)],
    ]
  end

  test 'pause a Run' do
    visit maintenance_tasks_path

    within 'tr', text: 'Maintenance::UpdatePostsTask' do
      click_on 'Run'
    end

    within 'table', text: 'Maintenance Task Runs' do
      within('tr', text: 'Maintenance::UpdatePostsTask') { click_on 'Pause' }
    end

    assert_table 'Maintenance Task Runs', with_rows: [
      ['Maintenance::UpdatePostsTask', I18n.l(Time.now.utc), 'paused'],
    ]
  end

  test 'run a task that errors' do
    with_inline_queue_adapter(Maintenance::ErrorTask) do
      visit maintenance_tasks_path

      within 'tr', text: 'Maintenance::ErrorTask' do
        click_on 'Run'
      end

      assert_text 'Task Maintenance::ErrorTask enqueued.'

      assert_table 'Maintenance Task Runs', with_rows: [
        [
          'Maintenance::ErrorTask',
          I18n.l(Time.now.utc),
          'errored',
          'ArgumentError',
          'Something went wrong',
          "app/jobs/maintenance/error_task.rb:9:in `task_iteration'",
        ],
      ]
    end
  end

  private

  def with_inline_queue_adapter(task)
    original_adapter = task.queue_adapter
    task.queue_adapter = :inline
    yield
  ensure
    task.queue_adapter = original_adapter
  end
end
