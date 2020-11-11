# frozen_string_literal: true

require 'application_system_test_case'

module MaintenanceTasks
  class TasksTest < ApplicationSystemTestCase
    test 'list all tasks' do
      visit maintenance_tasks_path

      assert_title 'Maintenance Tasks'

      assert_link 'Maintenance::UpdatePostsTask'
      assert_link 'Maintenance::ErrorTask'
    end

    test 'show a Task' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }

      assert_title 'Maintenance::UpdatePostsTask'

      assert_table rows: [
        [
          'January 01, 2020 01:00',
          'January 01, 2020 01:00',
          'succeeded',
          '10 / 10 (100%)',
          '',
          '',
          '',
          'January 01, 2020 01:00',
        ],
      ]
    end

    test 'list active Runs' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }

      click_on 'Run'

      visit maintenance_tasks_path

      assert_table 'running-tasks', rows: [
        [
          'Maintenance::UpdatePostsTask',
          'January 09, 2020 09:41',
          'enqueued',
          '',
        ],
      ]
    end

    test 'list completed Runs' do
      visit maintenance_tasks_path

      assert_table 'completed-tasks', rows: [
        [
          'Maintenance::UpdatePostsTask',
          'January 01, 2020 01:00',
          'January 01, 2020 01:00',
          'succeeded',
          'January 01, 2020 01:00',
        ],
      ]
    end

    test 'visit a Task page from an active Run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'

      visit maintenance_tasks_path

      within_table 'running-tasks' do
        click_on 'Maintenance::UpdatePostsTask'
      end

      assert_title 'Maintenance::UpdatePostsTask'
    end

    test 'visit a Task page from a completed Run' do
      visit maintenance_tasks_path

      within_table 'completed-tasks' do
        click_on 'Maintenance::UpdatePostsTask'
      end

      assert_title 'Maintenance::UpdatePostsTask'
    end
  end
end
