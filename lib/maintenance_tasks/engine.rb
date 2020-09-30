# frozen_string_literal: true
module MaintenanceTasks
  # The engine's main class, which defines its namespace. The engine is mounted
  # by the host application.
  class Engine < ::Rails::Engine
    isolate_namespace MaintenanceTasks
  end
end
