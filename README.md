# MaintenanceTasks

A Rails engine for queuing and managing maintenance tasks.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'maintenance_tasks'
```

And then execute:

```bash
$ bundle
$ rails generate maintenance_tasks:install
```

## Usage

TODO: You can generate tasks using:

```bash
$ rails generate maintenance_task
```

Or subclass `MaintenanceTasks::Task` and implement:

* `collection`: return an Active Record Relation or an Array to be iterated
  over.
* `process`: do the work of your maintenance task on a single record
* `count`: return the number of rows that will be iterated over (optional,
  to be able to show progress)

### Example

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

### Configuring the Gem

There are two configurable options for the gem.
Custom configurations should be placed in a `maintenance_tasks.rb` initializer.

`MaintenanceTasks.tasks_module` can be configured to define the module in which
tasks will be placed.
```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.tasks_module = 'TaskModule'
```
If no value is specified, it will default to `Maintenance`.

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
