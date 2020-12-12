# frozen_string_literal: true
require 'test_helper'
require 'generators/maintenance_tasks/install_generator'

module MaintenanceTasks
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests InstallGenerator
    SAMPLE_APP_PATH = Engine.root.join('tmp/sample_app')
    destination SAMPLE_APP_PATH
    setup :prepare_destination

    setup do
      skip 'This test is too slow' if ENV['SKIP_SLOW'].present?
      setup_sample_app
    end

    teardown do
      FileUtils.rm_rf(SAMPLE_APP_PATH)
    end

    test 'generator mounts engine and runs migrations' do
      Dir.chdir(SAMPLE_APP_PATH) do
        run_generator

        assert_file('config/routes.rb') do |contents|
          assert_match(
            %r{mount MaintenanceTasks::Engine => '/maintenance_tasks'},
            contents
          )
        end

        mig = 'db/migrate/create_maintenance_tasks_runs.maintenance_tasks.rb'
        assert_migration(mig)
        assert_file('db/schema.rb') do |contents|
          assert_match(/create_table "maintenance_tasks_runs"/, contents)
        end
      end
    end

    private

    def setup_sample_app
      FileUtils.copy_entry(Rails.root, SAMPLE_APP_PATH)

      Dir.chdir(SAMPLE_APP_PATH) do
        FileUtils.rm_r('db')
      end
    end
  end
end
