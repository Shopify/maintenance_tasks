# frozen_string_literal: true
GearedPagination::Engine.config.after_initialize do
  ActiveSupport.on_load(:action_controller) do
    ActionController::Base.skip_after_action(:set_paginated_headers)
  end
end
