# frozen_string_literal: true
module MaintenanceTasks
  # Class responsible for transitioning runs between statuses,
  # ensuring that only valid state transitions take place
  class RunStateMachine
    # Initializes a state machine
    #
    # @param run [MaintenanceTasks::Run] the run object to transition.
    def initialize(run)
      @run = run
    end

    # Transition a run to +running+ if it is enqueued
    def run
      return unless @run.enqueued?
      @run.running!
    end

    # Transition a run to +paused+ if it is enqueued or running
    def pause
      return unless @run.enqueued? || @run.running?
      @run.paused!
    end

    # Transition a run to +resumed+ if it is paused
    def resume
      return unless @run.paused?
      @run.enqueued!
    end

    # Transition a run to +interrupted+ if it is running
    def interrupt
      return unless @run.running?
      @run.interrupted!
    end

    # Transition a run to +succeeded+ if it is running or interrupted
    # The +interrupted+ -> +succeeded+ transition is a result of on_shutdown
    # callbacks occuring before on_complete callbacks in MaintenanceTasks::Task
    def complete
      return unless @run.running? || @run.interrupted?
      @run.succeeded!
    end

    # Transition a run to +errored+ if it is running
    def error
      return unless @run.running?
      @run.errored!
    end

    # Transition a run to +aborted+ if it is enqueued or running
    def abort
      return unless @run.enqueued? || @run.running?
      @run.aborted!
    end
  end
end
