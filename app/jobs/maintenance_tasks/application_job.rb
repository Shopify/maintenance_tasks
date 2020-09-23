# frozen_string_literal: true
require 'job-iteration'

module MaintenanceTasks
  class ApplicationJob < ActiveJob::Base
    include JobIteration::Iteration
  end
end
