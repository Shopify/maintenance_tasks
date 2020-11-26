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
        ['January 09, 2020 09:41', '', 'enqueued', '', '', '', ''],
      ]
      assert_no_button 'Run'
    end

    test 'pause a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Pause'

      assert_table with_rows: [
        ['January 09, 2020 09:41', '', 'pausing', '', '', '', ''],
      ]
    end

    test 'resume a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Pause'
      perform_enqueued_jobs
      page.refresh
      click_on 'Resume'

      assert_table with_rows: [
        ['January 09, 2020 09:41', '', 'enqueued', '', '', '', ''],
      ]
    end

    test 'cancel a Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'
      click_on 'Cancel'

      assert_table with_rows: [
        ['January 09, 2020 09:41', '', 'cancelling', '', '', '', ''],
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
          'January 09, 2020 09:41',
          'errored',
          '1',
          'ArgumentError',
          'Something went wrong',
          "app/tasks/maintenance/error_task.rb:9:in `process'",
          '',
          'January 09, 2020 09:41',
        ],
      ]
    end

    test 'errors are shown' do
      visit maintenance_tasks_path
      within('.menu') { click_on('Maintenance::UpdatePostsTask') }

      url = page.current_url
      using_session(:other_tab) do
        visit url
        click_on 'Run'
        click_on 'Pause'
      end

      click_on 'Run'

      assert_text 'Validation failed'
    end
  end
end
