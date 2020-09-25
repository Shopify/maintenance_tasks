# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  class Task < ActiveJob::Base
    include JobIteration::Iteration
  end
end
