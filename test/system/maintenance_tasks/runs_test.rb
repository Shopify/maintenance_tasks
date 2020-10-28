# frozen_string_literal: true

require 'application_system_test_case'

module MaintenanceTasks
  class RunsTest < ApplicationSystemTestCase
    test 'run a Task' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'

      assert_title 'Maintenance::UpdatePostsTask'
      assert_text 'Task Maintenance::UpdatePostsTask enqueued.'
      assert_table with_rows: [
        ['January 09, 2020 09:41', 'enqueued', '0', '', '', ''],
      ]
      assert_no_button 'Run'
    end

    test 'pause a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Pause'

      assert_table with_rows: [
        ['January 09, 2020 09:41', 'paused', '0', '', '', ''],
      ]
    end

    test 'resume a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Pause'
      click_on 'Resume'

      assert_table with_rows: [
        ['January 09, 2020 09:41', 'enqueued', '0', '', '', ''],
      ]
    end

    test 'cancel a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Cancel'

      assert_table with_rows: [
        ['January 09, 2020 09:41', 'cancelled', '0', '', '', ''],
      ]
    end

    test 'run a task that errors' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::ErrorTask') }

      perform_enqueued_jobs do
        click_on 'Run'
      end

      assert_text 'Task Maintenance::ErrorTask enqueued.'

      assert_table rows: [
        [
          'January 09, 2020 09:41',
          'errored',
          '0',
          'ArgumentError',
          'Something went wrong',
          "app/tasks/maintenance/error_task.rb:9:in `process'",
        ],
      ]
    end
  end
end
