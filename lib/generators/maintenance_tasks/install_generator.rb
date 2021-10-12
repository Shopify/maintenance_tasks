# frozen_string_literal: true

module MaintenanceTasks
  # Generator used to set up the engine in the host application. It handles
  # mounting the engine and installing migrations.
  #
  # @api private
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    # Mounts the engine in the host application's config/routes.rb
    def mount_engine
      route("mount MaintenanceTasks::Engine => \"/maintenance_tasks\"")
    end

    # Copies engine migrations to host application and migrates the database
    def install_migrations
      rake("maintenance_tasks:install:migrations")
      rake("db:migrate")
    end
  end
end
