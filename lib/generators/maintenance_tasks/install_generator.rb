# frozen_string_literal: true
module MaintenanceTasks
  # Generator used to set up the engine in the host application.
  # It handles mounting the engine, installing migrations
  # and creating some required files.
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    # Mounts the engine in the host application's config/routes.rb
    def mount_engine
      route("mount MaintenanceTasks::Engine => '/maintenance_tasks'")
    end

    # Copies engine migrations to host application and migrates the database
    def install_migrations
      rake('maintenance_tasks:install:migrations')
      rake('db:migrate')
    end

    # Creates an initializer file for the engine in the host application
    def create_initializer
      template(
        'maintenance_tasks.rb',
        'config/initializers/maintenance_tasks.rb'
      )
    end

    # Creates ApplicationTask class for task classes to subclass
    def create_application_task
      template(
        'application_task.rb',
        'app/tasks/maintenance/application_task.rb'
      )
    end
  end
end
