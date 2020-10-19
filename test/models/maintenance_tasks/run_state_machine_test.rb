# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunStateMachineTest < ActiveSupport::TestCase
    def setup
      @run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
    end

    test '#run transitions a run from +enqueued+ to +running+' do
      state_machine = RunStateMachine.new(@run)
      @run.enqueued!

      state_machine.run
      assert @run.running?

      assert_no_invalid_transitions([:enqueued]) do
        state_machine.run
      end
    end

    test '#pause transitions a run from +enqueued+ or +running+ to +paused+' do
      state_machine = RunStateMachine.new(@run)
      @run.enqueued!

      state_machine.pause
      assert @run.paused?

      @run.running!

      state_machine.pause
      assert @run.paused?

      assert_no_invalid_transitions([:enqueued, :running]) do
        state_machine.pause
      end
    end

    test '#resume transitions a run from +paused+ to +enqueued+' do
      state_machine = RunStateMachine.new(@run)
      @run.paused!

      state_machine.resume
      assert @run.enqueued?

      assert_no_invalid_transitions([:paused]) do
        state_machine.resume
      end
    end

    test '#interrupt transitions a run from +running+ to +interrupted+' do
      state_machine = RunStateMachine.new(@run)
      @run.running!

      state_machine.interrupt
      assert @run.interrupted?

      assert_no_invalid_transitions([:running]) do
        state_machine.interrupt
      end
    end

    test '#complete transitions a run from +running+ or +interrupted+ to +succeeded+' do
      state_machine = RunStateMachine.new(@run)
      @run.running!

      state_machine.complete
      assert @run.succeeded?

      @run.interrupted!

      state_machine.complete
      assert @run.succeeded?

      assert_no_invalid_transitions([:running, :interrupted]) do
        state_machine.complete
      end
    end

    test '#error transitions a run from +running+ to +errored+' do
      state_machine = RunStateMachine.new(@run)
      @run.running!

      state_machine.error
      assert @run.errored?

      assert_no_invalid_transitions([:running]) do
        state_machine.error
      end
    end

    test '#abort transitions a run from +enqueued+ or +running+ to +aborted+' do
      state_machine = RunStateMachine.new(@run)
      @run.enqueued!

      state_machine.abort
      assert @run.aborted?

      @run.running!

      state_machine.abort
      assert @run.aborted?

      assert_no_invalid_transitions([:enqueued, :running]) do
        state_machine.abort
      end
    end

    private

    def assert_no_invalid_transitions(valid_statuses)
      invalid_statuses = Run::STATUSES - valid_statuses
      invalid_statuses.each do |status|
        @run.update!(status: status)

        assert_no_changes(-> { @run.status }) do
          yield
        end
      end
    end
  end
end
