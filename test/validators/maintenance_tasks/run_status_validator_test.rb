# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunStatusValidatorTest < ActiveSupport::TestCase
    test 'run can go from enqueued or interrupted to running' do
      enqueued_run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      enqueued_run.status = :running

      assert enqueued_run.valid?

      interrupted_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :interrupted
      )
      interrupted_run.status = :running

      assert interrupted_run.valid?

      assert_no_invalid_transitions([:enqueued, :interrupted], :running)
    end

    test 'run can go from paused to enqueued' do
      paused_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :paused
      )
      paused_run.status = :enqueued

      assert paused_run.valid?

      assert_no_invalid_transitions([:paused], :enqueued)
    end

    test 'run can go from running or interrupted to succeeded' do
      running_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running
      )
      running_run.status = :succeeded

      assert running_run.valid?

      interrupted_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :interrupted
      )
      interrupted_run.status = :succeeded

      assert interrupted_run.valid?

      assert_no_invalid_transitions([:running, :interrupted], :succeeded)
    end

    test 'run can go from enqueued or running to cancelled' do
      enqueued_run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      enqueued_run.status = :cancelled

      assert enqueued_run.valid?

      running_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running
      )
      running_run.status = :cancelled

      assert running_run.valid?

      assert_no_invalid_transitions([:enqueued, :running], :cancelled)
    end

    test 'run can go from enqueued or running to paused' do
      enqueued_run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      enqueued_run.status = :paused

      assert enqueued_run.valid?

      running_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running
      )
      running_run.status = :paused

      assert running_run.valid?

      assert_no_invalid_transitions([:enqueued, :running], :paused)
    end

    test 'run can go from running to interrupted' do
      running_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running
      )
      running_run.status = :interrupted

      assert running_run.valid?

      assert_no_invalid_transitions([:running], :interrupted)
    end

    test 'run can go from running to errored' do
      running_run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running
      )
      running_run.status = :errored

      assert running_run.valid?

      assert_no_invalid_transitions([:running], :errored)
    end

    private

    def assert_no_invalid_transitions(valid_starting_statuses, end_status)
      invalid_statuses = Run::STATUSES - valid_starting_statuses - [end_status]
      invalid_statuses.each do |status|
        run = Run.create!(
          task_name: 'Maintenance::UpdatePostsTask',
          status: status
        )

        run.status = end_status

        refute(run.valid?,
          "Expected transition from #{status} to #{end_status} to be invalid")
        expected_status_error = [
          "Cannot transition run from status #{status} to #{end_status}",
        ]
        assert_equal(expected_status_error, run.errors[:status])
      end
    end
  end
end
