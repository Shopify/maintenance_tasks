# frozen_string_literal: true

require 'application_system_test_case'

class TasksTest < ApplicationSystemTestCase
  test 'list all tasks' do
    visit maintenance_tasks_path

    assert_title 'Maintenance Tasks'

    assert_table rows: [
      ['Maintenance::UpdatePostsTask', ''],
    ]
  end

  test 'run a task' do
    visit maintenance_tasks_path

    within 'tr', text: 'Maintenance::UpdatePostsTask' do
      click_on 'Run'
    end

    assert_title 'Maintenance Tasks'

    assert_text 'Task Maintenance::UpdatePostsTask enqueued.'
  end
end
