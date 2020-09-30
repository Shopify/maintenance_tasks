# frozen_string_literal: true
require 'test_helper'

class EnqueueTaskTest < ActionDispatch::IntegrationTest
  test 'enqueuing a task' do
    get '/maintenance_tasks'
    assert_response :success
    assert_select 'tbody tr td', 'Maintenance::UpdatePostsTask'

    assert_enqueued_with job: Maintenance::UpdatePostsTask do
      post '/maintenance_tasks/runs?name=Maintenance::UpdatePostsTask'
    end
    follow_redirect!
    assert_equal '/maintenance_tasks/', path
    assert_equal 'Task Maintenance::UpdatePostsTask enqueued.', flash[:notice]
  end
end
