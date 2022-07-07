# frozen_string_literal: true

MaintenanceTasks::Engine.routes.draw do
  resources :tasks, only: [:index, :show], format: false do
    member do
      put "run"
    end

    resources :runs, only: [], format: false do
      member do
        put "pause"
        put "cancel"
        put "resume"
      end
    end
  end

  root to: "tasks#index"
end
