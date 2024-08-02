# frozen_string_literal: true

Rails.application.routes.draw do
  mount MaintenanceTasks::Engine, at: "/maintenance_tasks"
  resources :posts
  root to: "posts#index"
end
