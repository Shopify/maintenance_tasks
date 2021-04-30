# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class TaskJob < ActiveJob::Base
    include TaskJobConcern
  end
end
