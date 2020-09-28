# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :runs
  root to: 'runs#index'
end
