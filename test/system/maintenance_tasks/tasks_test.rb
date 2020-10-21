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

      click_on 'Maintenance::UpdatePostsTask'

      assert_title 'Maintenance::UpdatePostsTask'
    end

    test 'lists active runs' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      visit maintenance_tasks_path

      assert_table with_rows: [
        ['Maintenance::UpdatePostsTask', I18n.l(Time.now.utc)],
      ]
    end

    test 'visit a task page from an active run' do
      visit maintenance_tasks_path

      click_on 'Maintenance::UpdatePostsTask'
      click_on 'Run'

      visit maintenance_tasks_path

      within 'tr', text: 'Maintenance::UpdatePostsTask' do
        click_on 'Maintenance::UpdatePostsTask'
      end

      assert_title 'Maintenance::UpdatePostsTask'
    end
  end
end
