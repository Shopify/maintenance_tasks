# frozen_string_literal: true
Rails.application.routes.draw do
  mount MaintenanceTasks::Engine => "/maintenance_tasks"
  resources :posts
  root to: "posts#index"
end
