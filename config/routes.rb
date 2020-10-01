# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :runs, only: [:index], format: false
  root to: 'runs#index'
end
