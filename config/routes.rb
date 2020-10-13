# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :runs, only: [:index, :create], format: false do
    member do
      put 'pause'
      put 'resume'
      put 'abort'
    end
  end

  root to: 'runs#index'
end
