# MaintenanceTasks

A Rails engine for queuing and managing maintenance tasks.

## Installation

Add this line to your application's Gemfile:

```ruby
source 'https://packages.shopify.io/shopify/gems' do
  gem 'maintenance_tasks'
end
```

And then execute:

```bash
$ bundle
$ rails generate maintenance_tasks:install
```

The generator creates and runs a migration to add the necessary table to your
database. It also mounts Mainteance Tasks in your `config/routes.rb`. By default
the web UI can be accessed in the new `/maintenance_tasks` path.

## Usage

### Creating a Task

A generator is provided to create tasks. Generate a new task by running:

```bash
$ rails generate maintenance_tasks:task update_posts
```

This creates the task file `app/tasks/maintenance/update_posts_task.rb`.

The generated task is a subclass of `MaintenanceTasks::Task` that implements:

* `collection`: return an Active Record Relation or an Array to be iterated
  over.
* `process`: do the work of your maintenance task on a single record
* `count`: return the number of rows that will be iterated over (optional,
  to be able to show progress)

Example:

```ruby
# app/tasks/maintenance/update_posts_task.rb
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    def collection
      Post.all
    end

    def count
      collection.count
    end

    def process(post)
      post.update!(content: 'New content!')
    end
  end
end
```

### Writing Tests for a Task

The task generator will also create a test file for your task in the folder
`test/tasks/maintenance/`. At a minimum, it's recommended that the `#process`
method in your task be tested. You may also want to test the `#collection` and
`#count` methods for your task if they are sufficiently complex.

Example:
```ruby
# test/tasks/maintenance/update_posts_task_test.rb

require 'test_helper'

module Maintenance
  class UpdatePostsTaskTest < ActiveSupport::TestCase
    test "#process performs a task iteration" do
      post = Post.new

      Maintenance::UpdatePostsTask.new.process(post)

      assert_equal 'New content!', post.content
    end
  end
end
```

### Running a Task

You can run your new Task by accessing the Web UI and clicking on "Run".

Alternatively, you can run your Task in the command line:

```bash
$ bundle exec maintenance_tasks perform Maintenance::UpdatePostsTask
```

You can also run a Task in Ruby by sending `run` with a Task name to a Runner
instance:

```ruby
MaintenanceTasks::Runner.new.run('Mainteance::UpdatePostsTask')
```

### Configuring the Gem

There are a couple configurable options for the gem.
Custom configurations should be placed in a `maintenance_tasks.rb` initializer.

#### Customizing the maintenance tasks module

`MaintenanceTasks.tasks_module` can be configured to define the module in which
tasks will be placed.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.tasks_module = 'TaskModule'
```

If no value is specified, it will default to `Maintenance`.

#### Customizing the underlying job class

`MaintenanceTasks.job` can be configured to define a Job class for your tasks
to use. This is a global configuration, so this Job class will be used across
all maintenance tasks in your application.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.job = 'CustomTaskJob'

# app/jobs/custom_task_job.rb
class CustomTaskJob < MaintenanceTasks::TaskJob
  queue_as :low_priority
end
```

The Job class **must inherit** from `MaintenanceTasks::TaskJob`.

Note that `retry_on` is not supported for custom Job
classes, so failed jobs cannot be retried.

#### Customizing the rate at which task progress gets updated

`MaintenanceTasks.ticker_delay` can be configured to customize how frequently
task progress gets persisted to the database. It can be a `Numeric` value or an
`ActiveSupport::Duration` value.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.ticker_delay = 2.seconds
```

If no value is specified, it will default to 1 second.

## Contributing

Would you like to report an issue or contribute with code? We accept issues and
pull requests. You can find the contribution guidelines on
[CONTRIBUTING.md](https://github.com/Shopify/maintenance_tasks/blob/main/.github/CONTRIBUTING.md).

## Releasing new versions

This gem is published to packagecloud. The procedure to publish a new version:

* Update `spec.version` in `maintenance_tasks.gemspec`.
* Run `bundle install` to bump the `Gemfile.lock` version of the gem.
* Open a PR and merge on approval.
* Create a [release on GitHub](https://help.github.com/articles/creating-releases/) with a version number that matches the version defined in the gemspec.
* Deploy via [Shipit](https://shipit.shopify.io/shopify/maintenance_tasks/packagecloud) and see the new version on https://gems.shopify.io/packages/.
