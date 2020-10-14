# frozen_string_literal: true

require 'application_system_test_case'

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
end
