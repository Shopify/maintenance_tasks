# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class RunStatusValidatorTest < ActiveSupport::TestCase
    test "run can go from enqueued or interrupted to running" do
      enqueued_run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      enqueued_run.status = :running

      assert enqueued_run.valid?

      interrupted_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :interrupted,
      )
      interrupted_run.status = :running

      assert interrupted_run.valid?

      assert_no_invalid_transitions([:enqueued, :interrupted], :running)
    end

    test "run can go from paused to enqueued" do
      paused_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      paused_run.status = :enqueued

      assert paused_run.valid?

      assert_no_invalid_transitions([:paused], :enqueued)
    end

    test "run can go from running, cancelling or pausing to succeeded" do
      running_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      running_run.status = :succeeded

      assert running_run.valid?

      pausing_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :pausing,
      )
      pausing_run.status = :succeeded

      assert pausing_run.valid?

      cancelling_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :cancelling,
      )
      cancelling_run.status = :succeeded

      assert cancelling_run.valid?

      assert_no_invalid_transitions(
        [:running, :pausing, :cancelling],
        :succeeded,
      )
    end

    test "run can go from enqueued, running, interrupted, or pausing to cancelling" do
      enqueued_run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      enqueued_run.status = :cancelling

      assert enqueued_run.valid?

      running_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      running_run.status = :cancelling

      assert running_run.valid?

      interrupted_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :interrupted,
      )
      interrupted_run.status = :cancelling

      assert interrupted_run.valid?

      pausing_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :pausing,
      )
      pausing_run.status = :cancelling

      assert pausing_run.valid?

      assert_no_invalid_transitions([:enqueued, :running, :interrupted, :pausing], :cancelling)
    end

    test "run can go from enqueued, interrupted or running to pausing" do
      enqueued_run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      enqueued_run.status = :pausing

      assert enqueued_run.valid?

      interrupted_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :interrupted,
      )
      interrupted_run.status = :pausing

      assert interrupted_run.valid?

      running_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      running_run.status = :pausing

      assert running_run.valid?

      assert_no_invalid_transitions([:enqueued, :interrupted, :running], :pausing)
    end

    test "run can go from pausing to paused" do
      pausing_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :pausing,
      )
      pausing_run.status = :paused

      assert pausing_run.valid?

      assert_no_invalid_transitions([:pausing], :paused)
    end

    test "run can go from cancelling or paused to cancelled" do
      cancelling_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :cancelling,
      )
      cancelling_run.status = :cancelled

      assert cancelling_run.valid?

      paused_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      paused_run.status = :cancelled

      assert paused_run.valid?

      assert_no_invalid_transitions([:cancelling, :paused], :cancelled)
    end

    test "run can go from running to interrupted" do
      running_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      running_run.status = :interrupted

      assert running_run.valid?

      assert_no_invalid_transitions([:running], :interrupted)
    end

    test "run can go from enqueued, running, pausing, interrupted or cancelling to errored" do
      enqueued_run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      enqueued_run.status = :errored

      assert enqueued_run.valid?

      running_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      running_run.status = :errored

      assert running_run.valid?

      pausing_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :pausing,
      )
      pausing_run.status = :errored

      assert pausing_run.valid?

      interrupted_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :interrupted,
      )
      interrupted_run.status = :errored

      assert interrupted_run.valid?

      cancelling_run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :cancelling,
      )
      cancelling_run.status = :errored

      assert cancelling_run.valid?

      assert_no_invalid_transitions([:enqueued, :running, :pausing, :interrupted, :cancelling], :errored)
    end

    private

    def assert_no_invalid_transitions(valid_starting_statuses, end_status)
      invalid_statuses = Run::STATUSES - valid_starting_statuses - [end_status]
      invalid_statuses.each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )

        run.status = end_status

        refute(run.valid?, "Expected transition from #{status} to #{end_status} to be invalid")
        expected_status_error = ["Cannot transition run from status #{status} to #{end_status}"]
        assert_equal(expected_status_error, run.errors[:status])
      end
    end
  end
end
