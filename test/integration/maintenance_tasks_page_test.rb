# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksPageTest < ActionDispatch::IntegrationTest
  test 'shows list of enqueueable tasks' do
    get maintenance_tasks_path

    assert_response :success
    assert_select('tr td', text: 'Maintenance::UpdatePostsTask')
  end
end
