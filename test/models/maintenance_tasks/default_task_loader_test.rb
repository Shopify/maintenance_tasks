# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class DefaultTaskLoaderTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    test ".load_all loads all autoloadable Task subclasses within the Maintenance namespace" do
      [
        Maintenance::BatchImportPostsTask,
        Maintenance::CallbackTestTask,
        Maintenance::CancelledEnqueueTask,
        Maintenance::EnqueueErrorTask,
        Maintenance::ErrorTask,
        Maintenance::ImportPostsTask,
        Maintenance::Nested,
        Maintenance::Nested::NestedMore,
        Maintenance::Nested::NestedMore::NestedMoreTask,
        Maintenance::Nested::NestedTask,
        Maintenance::NoCollectionTask,
        Maintenance::ParamsTask,
        Maintenance::TestTask,
        Maintenance::UpdatePostsInBatchesTask,
        Maintenance::UpdatePostsModulePrependedTask,
        Maintenance::UpdatePostsTask,
        Maintenance::UpdatePostsThrottledTask,
      ].each do |constant|
        constant
          .module_parent
          .expects(:const_get)
          .with(constant.name.demodulize.to_sym)
          .returns(constant)
      end

      DefaultTaskLoader.load_all
    end
  end
end
