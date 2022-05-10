# frozen_string_literal: true

module MaintenanceTasks
  class TaskPreviewsController < ApplicationController

    def show
      @task = TaskData.find(params.fetch(:id))

      binding.pry
    end
  end
end
