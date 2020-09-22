Rails.application.routes.draw do
  mount MaintenanceTasks::Engine => "/maintenance_tasks"
end
