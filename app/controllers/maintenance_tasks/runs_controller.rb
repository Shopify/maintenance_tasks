# frozen_string_literal: true

module MaintenanceTasks
  class RunsController < ApplicationController
    def index
      @available_tasks = Task.descendants
    end
  end
end
