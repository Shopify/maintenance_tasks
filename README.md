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
database. It also mounts Maintenance Tasks in your `config/routes.rb`. By
default the web UI can be accessed in the new `/maintenance_tasks` path.

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
* `count`: return the number of rows that will be iterated over (optional, to be
  able to show progress)

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
MaintenanceTasks::Runner.new.run('Maintenance::UpdatePostsTask')
```

### How Maintenance Tasks runs a Task

Maintenance tasks can be running for a long time, and the purpose of the gem is
to make it easy to continue running tasks through deploys, [Kubernetes Pod
scheduling][k8s-scheduling], [Heroku dyno restarts][heroku-cycles] or other
infrastructure or code changes.

[k8s-scheduling]: https://kubernetes.io/docs/concepts/scheduling-eviction/
[heroku-cycles]: https://www.heroku.com/dynos/lifecycle

This means a Task can safely be interrupted, re-enqueued and resumed without any
intervention at the end of an iteration, after the `process` method returns.

By default, a running Task will be interrupted after running for more 5 minutes.
This is [configured in the `job-iteration` gem][max-job-runtime] and can be
tweaked in an initializer if necessary.

[max-job-runtime]: https://github.com/Shopify/job-iteration/blob/master/guides/best-practices.md#max-job-runtime

Running tasks will also be interrupted and re-enqueued when needed. For example
[when Sidekiq workers shuts down for a deploy][sidekiq-deploy]:

[sidekiq-deploy]: https://github.com/mperham/sidekiq/wiki/Deployment

* When Sidekiq receives a TSTP or TERM signal, it will consider itself to be
  stopping.
* When Sidekiq is stopping, JobIteration stops iterating over the enumerator.
  The position in the iteration is saved, a new job is enqueued to resume work,
  and the Task is marked as interrupted.

When Sidekiq is stopping, it will give workers 25 seconds to finish before
forcefully terminating them (this is the default but can be configured with the
`--timeout` option).  Before the worker threads are terminated, Sidekiq will try
to re-enqueue the job so your Task will be resumed. However, the position in the
collection won't be persisted so at least one iteration may run again.

#### Help: my Task is stuck

Finally, if the queue adapter configured for your application doesn't have this
property, or if Sidekiq crashes, is forcefully terminated, or is unable to
re-enqueue the jobs that were in progress, the Task may be in a seemingly stuck
situation where it appears to be running but is not. In that situation, pausing
or cancelling it will not result in the Task being paused or cancelled, as the
Task will get stuck in a state of `pausing` or `cancelling`. As a work-around,
if a Task is `cancelling` for more than 5 minutes, you will be able to cancel it
for good, which will just mark it as cancelled, allowing you to run it again.

### Writing Tasks

MaintenanceTasks relies on the queue adapter configured for your application to
run the job which is processing your Task. The guidelines for writing Task may
depend on the queue adapter but in general, you should follow these rules:

* Duration of `Task#process`: processing a single element of the collection
  should take less than 25 seconds, or the duration set as a timeout for Sidekiq
  or the queue adapter configured in your application. It allows the Task to be
  safely interrupted and resumed.
* Idempotency of `Task#process`: it should be safe to run `process` multiple
  times for the same element of the collection. Read more in [this Sidekiq best
  practice][sidekiq-idempotent]. It's important if the Task errors and you run
  it again, because the same element that errored the Task may well be processed
  again. It especially matters in the situation described above, when the
  iteration duration exceeds the timeout: if the job is re-enqueued, multiple
  elements may be processed again.

[sidekiq-idempotent]: https://github.com/mperham/sidekiq/wiki/Best-Practices#2-make-your-job-idempotent-and-transactional

### Configuring the Gem

There are a few configurable options for the gem. Custom configurations should
be placed in a `maintenance_tasks.rb` initializer.

#### Customizing the error handler

Exceptions raised while a Task is performing are rescued and information about
the error is persisted and visible in the UI.

If your application uses Bugsnag to monitor errors, the gem will automatically
notify Bugsnag of any errors raised while a Task is performing.

If you want to integrate with another exception monitoring service or customize
error handling, a callback can be defined:

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.error_handler = ->(error) { MyErrorMonitor.notify(error) }
```

#### Customizing the maintenance tasks module

`MaintenanceTasks.tasks_module` can be configured to define the module in which
tasks will be placed.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.tasks_module = 'TaskModule'
```

If no value is specified, it will default to `Maintenance`.

#### Customizing the underlying job class

`MaintenanceTasks.job` can be configured to define a Job class for your tasks to
use. This is a global configuration, so this Job class will be used across all
maintenance tasks in your application.

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

## Upgrading

Use bundler to check for and upgrade to newer versions. After installing a new
version, re-run the install command:

```bash
$ rails generate maintenance_tasks:install
```

This ensures that new migrations are installed and run as well.

## Contributing

Would you like to report an issue or contribute with code? We accept issues and
pull requests. You can find the contribution guidelines on
[CONTRIBUTING.md][contributing].

[contributing]: https://github.com/Shopify/maintenance_tasks/blob/main/.github/CONTRIBUTING.md

## Releasing new versions

This gem is published to packagecloud. The procedure to publish a new version:

* Update `spec.version` in `maintenance_tasks.gemspec`.
* Run `bundle install` to bump the `Gemfile.lock` version of the gem.
* Open a PR and merge on approval.
* Create a [release on GitHub][release] with a version number that matches the
  version defined in the gemspec.
* Deploy via [Shipit][shipit] and see the new version on
  <https://gems.shopify.io/packages/>.

[release]: https://help.github.com/articles/creating-releases/
[shipit]: https://shipit.shopify.io/shopify/maintenance_tasks/packagecloud
