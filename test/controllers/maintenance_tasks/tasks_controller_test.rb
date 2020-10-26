# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TasksControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "#index has no Refresh header if there's no active run" do
      get tasks_url
      assert_nil meta_http_equiv_refresh
    end

    test "#index returns a Refresh header if there's an active run" do
      Run.new(task_name: 'Maintenance::UpdatePostsTask').enqueue
      get tasks_url
      refute_nil meta_http_equiv_refresh
    end

    test "#show has no Refresh header if there's no active run" do
      get task_url('Maintenance::UpdatePostsTask')
      assert_nil meta_http_equiv_refresh
    end

    test "#show returns a Refresh header if there's an active run" do
      Run.new(task_name: 'Maintenance::UpdatePostsTask').enqueue
      get task_url('Maintenance::UpdatePostsTask')
      refute_nil meta_http_equiv_refresh
    end

    def meta_http_equiv_refresh
      body[/<meta http-equiv="refresh" content="\d+">/]
    end
  end
end
