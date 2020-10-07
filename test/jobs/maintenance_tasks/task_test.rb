# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveJob::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = ['Maintenance::UpdatePostsTask']
      assert_equal expected, MaintenanceTasks::Task.available_tasks.map(&:name)
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end

    test 'can be enqueued without a Run' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        Maintenance::UpdatePostsTask.perform_later
      end
    end

    test 'can be enqueued with a Run' do
      run = Run.create(task_name: Maintenance::UpdatePostsTask)

      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        Maintenance::UpdatePostsTask.perform_later(run: run)
      end
    end

    test 'updates job_id on Run when performed with a run' do
      run = Run.create(task_name: Maintenance::UpdatePostsTask)
      job = Maintenance::UpdatePostsTask.perform_later(run: run)

      perform_enqueued_jobs

      assert_equal job.job_id, run.reload.job_id
    end
  end
end
