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

    test 'visit a task page' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }

      assert_title 'Maintenance::UpdatePostsTask'
    end

    test 'lists active runs' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'

      visit maintenance_tasks_path

      assert_table 'running-tasks', with_rows: [
        ['Maintenance::UpdatePostsTask', 'January 01, 2020 01:00'],
      ]
    end

    test 'list completed runs' do
      visit maintenance_tasks_path

      assert_table 'completed-tasks', with_rows: [
        ['Maintenance::UpdatePostsTask', 'January 01, 2020 01:00'],
      ]
    end

    test 'visit a task page from an active run' do
      visit maintenance_tasks_path

      within('.menu') { click_on('Maintenance::UpdatePostsTask') }
      click_on 'Run'

      visit maintenance_tasks_path

      within_table 'running-tasks' do
        click_on 'Maintenance::UpdatePostsTask'
      end

      assert_title 'Maintenance::UpdatePostsTask'
    end

    test 'visit a task page from a completed run' do
      visit maintenance_tasks_path

      within_table 'completed-tasks' do
        click_on 'Maintenance::UpdatePostsTask'
      end

      assert_title 'Maintenance::UpdatePostsTask'
    end
  end
end
