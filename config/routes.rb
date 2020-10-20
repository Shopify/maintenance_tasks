# frozen_string_literal: true
MaintenanceTasks::Engine.routes.draw do
  resources :tasks, only: [:index, :show], format: false do
    resources :runs, only: [:create], format: false do
      member do
        put 'pause'
        put 'resume'
        put 'cancel'
      end
    end
  end

  root to: 'tasks#index'
end
