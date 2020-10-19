# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  class ApplicationController < ActionController::Base
    include Pagy::Backend

    protect_from_forgery with: :exception
  end
end
