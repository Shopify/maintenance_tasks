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

    test 'lists tasks by category' do
      visit maintenance_tasks_path

      expected = [
        'New Tasks',
        "Maintenance::CancelledEnqueueTask\nNew",
        "Maintenance::EnqueueErrorTask\nNew",
        "Maintenance::ErrorTask\nNew",
        "Maintenance::TestCsvTask\nNew",
        "Maintenance::TestTask\nNew",
        'Completed Tasks',
        "Maintenance::UpdatePostsTask\nSucceeded",
      ]

      assert_equal expected, page.all('h3').map(&:text)
    end

    test 'show a Task' do
      visit maintenance_tasks_path

      click_on('Maintenance::UpdatePostsTask')

      assert_title 'Maintenance::UpdatePostsTask'
      assert_text 'Succeeded'
      assert_text 'Ran for less than 5 seconds, finished 8 days ago.'
    end

    test 'show a deleted Task' do
      visit maintenance_tasks_path + '/tasks/Maintenance::DeletedTask'

      assert_title 'Maintenance::DeletedTask'
      assert_text 'Succeeded'
      assert_button 'Run', disabled: true
    end

    test 'visit main page through iframe' do
      visit root_path

      within_frame('maintenance-tasks-iframe') do
        assert_content 'Maintenance Tasks'
      end
    end
  end
end
