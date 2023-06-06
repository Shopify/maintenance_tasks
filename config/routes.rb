# frozen_string_literal: true

MaintenanceTasks::Engine.routes.draw do
  get '/search', to: "tasks#search"
  resources :tasks, only: [:index, :show], format: false do
    resources :runs, only: [:create], format: false do
      member do
        put "pause"
        put "cancel"
        put "resume"
      end
    end
  end

  root to: "tasks#index"
end
