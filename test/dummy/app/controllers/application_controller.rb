# frozen_string_literal: true

class ApplicationController < ActionController::Base
  around_action :set_timezone

  private

  def set_timezone(&block)
    Time.use_zone("Melbourne", &block)
  end
end
