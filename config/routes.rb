# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :runs, only: [:index, :create], format: false do
    put 'pause', on: :member
  end

  root to: 'runs#index'
end
