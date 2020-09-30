# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :runs, only: [:index, :create], format: false
  root to: 'runs#index'
end
