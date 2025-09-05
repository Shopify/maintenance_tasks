# Maintenance Tasks

A Rails engine for queuing and managing maintenance tasks.

By ”maintenance task”, this project means a data migration, i.e. code that
changes data in the database, often to support schema migrations. For example,
in order to introduce a new `NOT NULL` column, it has to be added as nullable
first, backfilled with values, before finally being changed to `NOT NULL`. This
engine helps with the second part of this process, backfilling.

Maintenance tasks are collection-based tasks, usually using Active Record, that
update the data in your database. They can be paused or interrupted. Maintenance
tasks can operate [in batches](#processing-batch-collections) and use
[throttling](#throttling) to control the load on your database.

Maintenance tasks aren't meant to happen on a regular basis. They're used as
needed, or as one-offs. Normally maintenance tasks are ephemeral, so they are
used briefly and then deleted.

The Rails engine has a web-based UI for listing maintenance tasks, seeing their
status, and starting, pausing and restarting them.

[![Link to demo video](static/demo.png)](https://www.youtube.com/watch?v=BTuvTQxlFzs)

## Should I Use Maintenance Tasks?

Maintenance tasks have a limited, specific job UI. While the engine can be used
to provide a user interface for other data changes, such as data changes for
support requests, we recommend you use regular application code for those use
cases instead. These inevitably require more flexibility than this engine will
be able to provide.

If your task shouldn't run as an Active Job, it probably isn't a good match for
this gem. If your task doesn't need to run in the background, consider a runner
script instead. If your task doesn't need to be interruptible, consider a normal
Active Job.

Maintenance tasks can be interrupted between iterations. If your task [isn't
collection-based](#tasks-that-dont-need-a-collection) (no CSV file or database
table) or has very large batches, it will get limited benefit from throttling
(pausing between iterations) or interrupting. This might be fine, or the added
complexity of maintenance Tasks over normal Active Jobs may not be worthwhile.

If your task updates your database schema instead of data, use a migration
instead of a maintenance task.

If your task happens regularly, consider Active Jobs with a scheduler or cron,
[job-iteration jobs][job-iteration] and/or [custom rails_admin
UIs][rails-admin-engines] instead of the Maintenance Tasks gem. Maintenance
tasks should be ephemeral, to suit their intentionally limited UI. They should
not repeat.

[job-iteration]: https://github.com/shopify/job-iteration

To create seed data for a new application, use the provided Rails `db/seeds.rb`
file instead.

If your application can't handle a half-completed migration, maintenance tasks
are probably the wrong tool. Remember that maintenance tasks are intentionally
pausable and can be cancelled halfway.

[rails-admin-engines]: https://www.ruby-toolbox.com/categories/rails_admin_interfaces

## Installation

To install the gem and run the install generator, execute:

```sh-session
bundle add maintenance_tasks
bin/rails generate maintenance_tasks:install
```

The generator creates and runs a migration to add the necessary table to your
database. It also mounts Maintenance Tasks in your `config/routes.rb`. By
default the web UI can be accessed in the new `/maintenance_tasks` path.

This gem uses the [Rails Error Reporter][rails-error-reporting] to report errors.
If you are using a bug tracking service you may want to subscribe to the
reporter. See [Reporting Errors](#reporting-errors) for more information.

[rails-error-reporting]: https://guides.rubyonrails.org/error_reporting.html

### Active Job Dependency

The Maintenance Tasks framework relies on Active Job behind the scenes to run
Tasks. The default queuing backend for Active Job is
[asynchronous][async-adapter]. It is **strongly recommended** to change this to
a persistent backend so that Task progress is not lost during code or
infrastructure changes. For more information on configuring a queuing backend,
take a look at the [Active Job documentation][active-job-docs].

[async-adapter]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/AsyncAdapter.html
[active-job-docs]: https://guides.rubyonrails.org/active_job_basics.html#setting-the-backend

### Action Controller & Action View Dependency

The Maintenance Tasks framework relies on Action Controller and Action View to
render the UI. If you're using Rails in API-only mode, see [Using Maintenance
Tasks in API-only
applications](#using-maintenance-tasks-in-api-only-applications).

### Autoloading

The Maintenance Tasks framework does not support autoloading in `:classic` mode.
Please ensure your application is using [Zeitwerk][] to load your code. For more
information, please consult the [Rails guides on autoloading and reloading
constants][autoloading].

[Zeitwerk]: https://github.com/fxn/zeitwerk
[autoloading]: https://guides.rubyonrails.org/autoloading_and_reloading_constants.html

## Usage

The typical Maintenance Tasks workflow is as follows:

1. [Generate a class describing the Task](#creating-a-task) and the work to be
   done.
2. Run the Task
   - either by [using the included web UI](#running-a-task-from-the-web-ui),
   - or by [using the command line](#running-a-task-from-the-command-line),
   - or by [using Ruby](#running-a-task-from-ruby).
3. [Monitor the Task](#monitoring-your-tasks-status)
   - either by using the included web UI,
   - or by manually checking your task’s run’s status in your database.
4. Optionally, delete the Task code if you no longer need it.

### Creating a Task

A generator is provided to create tasks. Generate a new task by running:

```sh-session
bin/rails generate maintenance_tasks:task update_posts
```

This creates the task file `app/tasks/maintenance/update_posts_task.rb`.

The generated task is a subclass of `MaintenanceTasks::Task` that implements:

* `collection`: return an Active Record Relation or an Array to be iterated
  over.
* `process`: do the work of your maintenance task on a single record

Optionally, tasks can also implement a custom `#count` method, defining the
number of elements that will be iterated over. Your task’s `tick_total` will be
calculated automatically based on the collection size, but this value may be
overridden if desired using the `#count` method (this might be done, for
example, to avoid the query that would be produced to determine the size of your
collection).

Example:

```ruby
# app/tasks/maintenance/update_posts_task.rb

module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    def collection
      Post.all
    end

    def process(post)
      post.update!(content: "New content!")
    end
  end
end
```

#### Customizing the Batch Size

When processing records from an Active Record Relation, records are fetched in
batches internally, and then each record is passed to the `#process` method.
Maintenance Tasks will query the database to fetch records in batches of 100 by
default, but the batch size can be modified using the `collection_batch_size`
macro:

```ruby
# app/tasks/maintenance/update_posts_task.rb

module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    # Fetch records in batches of 1000
    collection_batch_size(1000)

    def collection
      Post.all
    end

    def process(post)
      post.update!(content: "New content!")
    end
  end
end
```

### Creating a CSV Task

You can also write a Task that iterates on a CSV file. Note that writing CSV
Tasks **requires Active Storage to be configured**. Ensure that the dependency
is specified in your application’s Gemfile, and that you’ve followed the [setup
instructions][storage-setup]. See also [Customizing which Active Storage service
to use][storage-customizing].

[storage-setup]: https://edgeguides.rubyonrails.org/active_storage_overview.html#setup
[storage-customizing]: #customizing-which-active-storage-service-to-use

Generate a CSV Task by running:

```sh-session
bin/rails generate maintenance_tasks:task import_posts --csv
```

The generated task is a subclass of `MaintenanceTasks::Task` that implements:

* `process`: do the work of your maintenance task on a `CSV::Row`

```ruby
# app/tasks/maintenance/import_posts_task.rb

module Maintenance
  class ImportPostsTask < MaintenanceTasks::Task
    csv_collection

    def process(row)
      Post.create!(title: row["title"], content: row["content"])
    end
  end
end
```

`posts.csv`:
```csv
title,content
My Title,Hello World!
```

The files uploaded to your Active Storage service provider will be renamed to
include an ISO 8601 timestamp and the Task name in snake case format.

The implicit `#count` method loads and parses the entire file to determine the
accurate number of rows. With files with millions of rows, it takes several
seconds to process. Consider skipping the count (defining a `count` that returns
`nil`) or use an approximation, eg: count the number of new lines:

```ruby
def count(task)
  task.csv_content.count("\n") - 1
end
```

#### CSV options

Tasks can pass [options for Ruby's CSV parser][csv-parse-options] by adding
keyword arguments to `csv_collection`:

[csv-parse-options]: https://ruby-doc.org/3.3.0/stdlibs/csv/CSV.html#class-CSV-label-Options+for+Parsing

```ruby
# app/tasks/maintenance/import_posts_task.rb

module Maintenance
  class ImportPosts
    csv_collection(skip_lines: /^#/, converters: ->(field) { field.strip })

    def process(row)
      Post.create!(title: row["title"], content: row["content"])
    end
  end
end
```

These options instruct Ruby's CSV parser to skip lines that start with a `#`,
and removes the leading and trailing spaces from any field, so that the
following file will be processed identically as the previous example:

`posts.csv`:
```csv
# A comment
title,content
 My Title ,Hello World!
```

#### Batch CSV Tasks

Tasks can process CSVs in batches. Add the `in_batches` option to your task’s
`csv_collection` macro:

```ruby
# app/tasks/maintenance/batch_import_posts_task.rb

module Maintenance
  class BatchImportPostsTask < MaintenanceTasks::Task
    csv_collection(in_batches: 50)

    def process(batch_of_rows)
      Post.insert_all(post_rows.map(&:to_h))
    end
  end
end
```

As with a regular CSV task, ensure you’ve implemented the following method:

* `process`: do the work of your Task on a batch (array of `CSV::Row` objects).

Note that `#count` is calculated automatically based on the number of batches in
your collection, and your Task’s progress will be displayed in terms of batches
(not the total number of rows in your CSV).

Non-batched CSV tasks will have an effective batch size of 1, which can reduce
the efficiency of your database operations.

### Processing Batch Collections

The Maintenance Tasks gem supports processing Active Records in batches. This
can reduce the number of calls your Task makes to the database. Use
`ActiveRecord::Batches#in_batches` on the relation returned by your collection
to specify that your Task should process batches instead of records. Active
Record defaults to 1000 records by batch, but a custom size can be specified.

```ruby
# app/tasks/maintenance/update_posts_in_batches_task.rb

module Maintenance
  class UpdatePostsInBatchesTask < MaintenanceTasks::Task
    def collection
      Post.in_batches
    end

    def process(batch_of_posts)
      batch_of_posts.update_all(content: "New content added on #{Time.now.utc}")
    end
  end
end
```

Ensure that you’ve implemented the following methods:

* `collection`: return an `ActiveRecord::Batches::BatchEnumerator`.
* `process`: do the work of your Task on a batch (`ActiveRecord::Relation`).

Note that `#count` is calculated automatically based on the number of batches in
your collection, and your Task’s progress will be displayed in terms of batches
(not the number of records in the relation).

**Important!** Batches should only be used if `#process` is performing a batch
operation such as `#update_all` or `#delete_all`. If you need to iterate over
individual records, you should define a collection that [returns an
`ActiveRecord::Relation`](#creating-a-task). This uses batching internally, but
loads the records with one SQL query. Conversely, batch collections load the
primary keys of the records of the batch first, and then perform an additional
query to load the records when calling `each` (or any `Enumerable` method)
inside `#process`.

### Tasks that don’t need a Collection

Sometimes, you might want to run a Task that performs a single operation, such
as enqueuing another background job or querying an external API. The gem
supports collection-less tasks.

Generate a collection-less Task by running:

```sh-session
bin/rails generate maintenance_tasks:task no_collection_task --no-collection
```

The generated task is a subclass of `MaintenanceTasks::Task` that implements:

* `process`: do the work of your maintenance task

```ruby
# app/tasks/maintenance/no_collection_task.rb

module Maintenance
  class NoCollectionTask < MaintenanceTasks::Task
    no_collection

    def process
      SomeAsyncJob.perform_later
    end
  end
end
```

### Tasks with Custom Enumerators

If you have a special use case requiring iteration over an unsupported
collection type, such as external resources fetched from some API, you can
implement the `enumerator_builder(cursor:)` method in your task.

This method should return an `Enumerator`, yielding pairs of `[item, cursor]`.
Maintenance Tasks takes care of persisting the current cursor position and will
provide it as the `cursor` argument if your task is interrupted or resumed. The
`cursor` is stored as a `String`, so your custom enumerator should handle
serializing/deserializing the value if required.

```ruby
# app/tasks/maintenance/custom_enumerator_task.rb

module Maintenance
  class CustomEnumeratorTask < MaintenanceTasks::Task
    def enumerator_builder(cursor:)
      after_id = cursor&.to_i
      PostAPI.index(after_id: after_id).map { |post| [post, post.id] }.to_enum
    end

    def process(post)
      Post.create!(post)
    end
  end
end
```

### Throttling

Maintenance tasks often modify a lot of data and can be taxing on your database.
The gem provides a throttling mechanism that can be used to throttle a Task when
a given condition is met. If a Task is throttled (the throttle block returns
true), it will be interrupted and retried after a backoff period has passed. The
default backoff is 30 seconds.

Specify the throttle condition as a block:

```ruby
# app/tasks/maintenance/update_posts_throttled_task.rb

module Maintenance
  class UpdatePostsThrottledTask < MaintenanceTasks::Task
    throttle_on(backoff: 1.minute) do
      DatabaseStatus.unhealthy?
    end

    def collection
      Post.all
    end

    def process(post)
      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
```

Note that it’s up to you to define a throttling condition that makes sense for
your app. Shopify implements `DatabaseStatus.healthy?` to check various MySQL
metrics such as replication lag, DB threads, whether DB writes are available,
etc.

Tasks can define multiple throttle conditions. Throttle conditions are inherited
by descendants, and new conditions will be appended without impacting existing
conditions.

The backoff can also be specified as a Proc that receives no arguments:

```ruby
# app/tasks/maintenance/update_posts_throttled_task.rb

module Maintenance
  class UpdatePostsThrottledTask < MaintenanceTasks::Task
    throttle_on(backoff: -> { RandomBackoffGenerator.generate_duration } ) do
      DatabaseStatus.unhealthy?
    end
    # ...
  end
end
```

### Custom Task Parameters

Tasks may need additional information, supplied via parameters, to run.
Parameters can be defined as Active Model Attributes in a Task, and then become
accessible to any of Task’s methods: `#collection`, `#count`, or `#process`.

```ruby
# app/tasks/maintenance/update_posts_via_params_task.rb

module Maintenance
  class UpdatePostsViaParamsTask < MaintenanceTasks::Task
    attribute :updated_content, :string
    validates :updated_content, presence: true

    def collection
      Post.all
    end

    def process(post)
      post.update!(content: updated_content)
    end
  end
end
```

Tasks can leverage Active Model Validations when defining parameters. Arguments
supplied to a Task accepting parameters will be validated before the Task starts
to run. Since arguments are specified in the user interface via text area
inputs, it’s important to check that they conform to the format your Task
expects, and to sanitize any inputs if necessary.

#### Validating Task Parameters

Task attributes can be validated using Active Model Validations. Attributes are
validated before a Task is enqueued.

If an attribute uses an inclusion validator with a supported `in:` option, the
set of values will be used to populate a dropdown in the user interface. The
following types are supported:

* Arrays
* Procs and lambdas that optionally accept the Task instance, and return an
  Array.
* Callable objects that receive one argument, the Task instance, and return an
  Array.
* Methods that return an Array, called on the Task instance.

For enumerables that don't match the supported types, a text field will be
rendered instead.

### Masking Task Parameters

Task attributes can be masked in the UI by adding `mask_attribute` class method
in the task class. This will replace the value in the arguments list with
`[FILTERED]` in the UI.

```ruby
# app/tasks/maintenance/sensitive_params_task.rb

module Maintenance
  class SensitiveParamsTask < MaintenanceTasks::Task
    attribute :sensitive_content, :string

    mask_attribute :sensitive_content
  end
end
```

If you have any filtered parameters in the global [Rails parameter
filter][rails-parameter-filter], they will be automatically taken into account
when masking the parameters, which means that you can mask parameters across all
tasks by adding them to the global rails parameters filter.

[rails-parameter-filter]:https://guides.rubyonrails.org/configuring.html#config-filter-parameters

```ruby
Rails.application.config.filter_parameters += %i[token]
```

### Custom cursor columns to improve performance

The [job-iteration gem][job-iteration], on which this gem depends, adds an
`order by` clause to the relation returned by the `collection` method, in order
to iterate through records. It defaults to order on the `id` column.

The [job-iteration gem][job-iteration] supports configuring which columns are
used to order the cursor, as documented in
[`build_active_record_enumerator_on_records`][ji-ar-enumerator-doc].

[ji-ar-enumerator-doc]: https://www.rubydoc.info/gems/job-iteration/JobIteration/EnumeratorBuilder#build_active_record_enumerator_on_records-instance_method

The `maintenance-tasks` gem exposes the ability that `job-iteration` provides to
control the cursor columns, through the `cursor_columns` method in the
`MaintenanceTasks::Task` class. If the `cursor_columns` method returns `nil`,
the query is ordered by the primary key. If cursor columns values change during
an iteration, records may be skipped or yielded multiple times.

```ruby
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    def cursor_columns
      [:created_at, :id]
    end

    def collection
      Post.where(created_at: 2.days.ago...1.hour.ago)
    end

    def process(post)
      post.update!(content: "updated content")
    end
  end
end
```

### Task Output

Maintenance Tasks can store and collect task outputs, which is displayed on the Web UI.

How the output is stored depends entirely on the Task implementation, being it on the primary database, logs, cache, file system, etc.

To use this feature, define the `output` reader and writer methods, then write the output in the `process` method or in a callback.

The task methods have access to a subset of the `Run` instance information in the `run_data` method.

```ruby
module Maintenance
  class CacheOutputTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(item)
      self.output = output.to_s + "Processing item #{item}.\n"
    end

    def output=(message)
      SomeStorage.write("maintenance-tasks:#{run_data.id}", message)
    end

    def output
      SomeStorage.read("maintenance-tasks:#{run_data.id}")
    end
  end
end
```

### Subscribing to instrumentation events

If you are interested in actioning a specific task event, please refer to the
[Using Task Callbacks](#using-task-callbacks) section below. However, if you
want to subscribe to all events, irrespective of the task, you can use the
following Active Support notifications:

```ruby
enqueued.maintenance_tasks    # This event is published when a task has been enqueued by the user.
succeeded.maintenance_tasks   # This event is published when a task has finished without any errors.
cancelled.maintenance_tasks   # This event is published when the user explicitly halts the execution of a task.
paused.maintenance_tasks      # This event is published when a task is paused by the user in the middle of its run.
errored.maintenance_tasks     # This event is published when the task's code produces an unhandled exception.
```

These notifications offer a way to monitor the lifecycle of maintenance tasks in
your application.

Usage example:

```ruby
ActiveSupport::Notifications.subscribe("succeeded.maintenance_tasks") do |*, payload|
  task_name = payload[:task_name]
  arguments = payload[:arguments]
  metadata = payload[:metadata]
  job_id = payload[:job_id]
  run_id = payload[:run_id]
  time_running = payload[:time_running]
  started_at = payload[:started_at]
  ended_at = payload[:ended_at]
rescue => e
  Rails.logger.error(e)
end

ActiveSupport::Notifications.subscribe("errored.maintenance_tasks") do |*, payload|
  task_name = payload[:task_name]
  error = payload[:error]
  error_message = error[:message]
  error_class = error[:class]
  error_backtrace = error[:backtrace]
rescue => e
  Rails.logger.error(e)
end

# or

class MaintenanceTasksInstrumenter < ActiveSupport::Subscriber
  attach_to :maintenance_tasks

  def enqueued(event)
    task_name = event.payload[:task_name]
    arguments = event.payload[:arguments]
    metadata = event.payload[:metadata]

    SlackNotifier.broadcast(SLACK_CHANNEL,
      "Job #{task_name} was started by #{metadata[:user_email]}} with arguments #{arguments.to_s.truncate(255)}")
  rescue => e
    Rails.logger.error(e)
  end
end
```

### Using Task Callbacks

The Task provides callbacks that hook into its life cycle.

Available callbacks are:

* `after_start`
* `after_pause`
* `after_interrupt`
* `after_cancel`
* `after_complete`
* `after_error`

```ruby
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    after_start :notify

    def notify
      NotifyJob.perform_later(self.class.name)
    end

    # ...
  end
end
```

Note: The `after_error` callback is guaranteed to complete, so any exceptions
raised in your callback code are ignored. If your `after_error` callback code
can raise an exception, you’ll need to rescue it and handle it appropriately
within the callback.

```ruby
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    after_error :dangerous_notify

    def dangerous_notify
      # This error is rescued and ignored in favour of the original error causing the error flow.
      raise NotDeliveredError
    end

    # ...
  end
end
```

If any of the other callbacks cause an exception, it will be handled by the
error handler, and will cause the task to stop running.

### Considerations when writing Tasks

Maintenance Tasks relies on the queue adapter configured for your application to
run the job which is processing your Task. The guidelines for writing Task may
depend on the queue adapter but in general, you should follow these rules:

* Duration of `Task#process`: processing a single element of the collection
  should take less than 25 seconds, or the duration set as a timeout for Sidekiq
  or the queue adapter configured in your application. Short batches allow the
  Task to be safely interrupted and resumed.
* Idempotency of `Task#process`: it should be safe to run `process` multiple
  times for the same element of the collection. Read more in [this Sidekiq best
  practice][sidekiq-idempotent]. It’s important if the Task errors and you run
  it again, because the same element that caused the Task to give an error may
  well be processed again. It especially matters in the situation described
  above, when the iteration duration exceeds the timeout: if the job is
  re-enqueued, multiple elements may be processed again.

[sidekiq-idempotent]: https://github.com/mperham/sidekiq/wiki/Best-Practices#2-make-your-job-idempotent-and-transactional

#### Task object life cycle and memoization

When the Task runs or resumes, the Runner enqueues a job, which processes the
Task. That job will instantiate a Task object which will live for the duration
of the job. The first time the job runs, it will call `count`. Every time a job
runs, it will call `collection` on the Task object, and then `process` for each
item in the collection, until the job stops. The job stops when either the
collection is finished processing or after the maximum job runtime has expired.

This means memoization can be misleading within `process`, since the memoized
values will be available for subsequent calls to `process` within the same job.
Still, memoization can be used for throttling or reporting, and you can use
[Task callbacks](#using-task-callbacks) to persist or log a report for example.

### Writing tests for a Task

The task generator will also create a test file for your task in the folder
`test/tasks/maintenance/`. At a minimum, it’s recommended that the `#process`
method in your task be tested. You may also want to test the `#collection` and
`#count` methods for your task if they are sufficiently complex.

Example:

```ruby
# test/tasks/maintenance/update_posts_task_test.rb

require "test_helper"

module Maintenance
  class UpdatePostsTaskTest < ActiveSupport::TestCase
    test "#process performs a task iteration" do
      post = Post.new

      Maintenance::UpdatePostsTask.process(post)

      assert_equal "New content!", post.content
    end
  end
end
```

### Writing tests for a CSV Task

You should write tests for your `#process` method in a CSV Task as well. It
takes a `CSV::Row` as an argument. You can pass a row, or a hash with string
keys to `#process` from your test.

```ruby
# test/tasks/maintenance/import_posts_task_test.rb

require "test_helper"

module Maintenance
  class ImportPostsTaskTest < ActiveSupport::TestCase
    test "#process performs a task iteration" do
      assert_difference -> { Post.count } do
        Maintenance::UpdatePostsTask.process({
          "title" => "My Title",
          "content" => "Hello World!",
        })
      end

      post = Post.last
      assert_equal "My Title", post.title
      assert_equal "Hello World!", post.content
    end
  end
end
```

### Writing tests for a Task with parameters

Tests for tasks with parameters need to instantiate the task class in order to
assign attributes. Once the task instance is setup, you may test `#process`
normally.

```ruby
# test/tasks/maintenance/update_posts_via_params_task_test.rb

require "test_helper"

module Maintenance
  class UpdatePostsViaParamsTaskTest < ActiveSupport::TestCase
    setup do
      @task = UpdatePostsViaParamsTask.new
      @task.updated_content = "Testing"
    end

    test "#process performs a task iteration" do
      assert_difference -> { Post.first.content } do
        @task.process(Post.first)
      end
    end
  end
end
```

### Writing tests for a Task that uses a custom enumerator

Tests for tasks that use custom enumerators need to instantiate the task class
in order to call `#enumerator_builder`. Once the task instance is set up,
validate that `#enumerator_builder` returns an enumerator yielding pairs of
`[item, cursor]` as expected.

```ruby
# test/tasks/maintenance/custom_enumerating_task.rb

require "test_helper"

module Maintenance
  class CustomEnumeratingTaskTest < ActiveSupport::TestCase
    setup do
      @task = CustomEnumeratingTask.new
    end

    test "#enumerator_builder returns enumerator yielding pairs of [item, cursor]" do
      enum = @task.enumerator_builder(cursor: 0)
      expected_items = [:b, :c]

      assert_equal 2, enum.size

      enum.each_with_index do |item, cursor|
        assert_equal expected_items[cursor], item
      end
    end

    test "#process performs a task iteration" do
      # ...
    end
  end
end
```

### Running a Task

#### Running a Task from the Web UI

You can run your new Task by accessing the Web UI and clicking on "Run".

#### Running a Task from the command line

Alternatively, you can run your Task in the command line:

```sh-session
bundle exec maintenance_tasks perform Maintenance::UpdatePostsTask
```

To run a Task that processes CSVs from the command line, use the `--csv` option:

```sh-session
bundle exec maintenance_tasks perform Maintenance::ImportPostsTask --csv "path/to/my_csv.csv"
```

The `--csv` option also works with CSV content coming from the standard input:

```sh-session
curl "some/remote/csv" |
  bundle exec maintenance_tasks perform Maintenance::ImportPostsTask --csv
```

To run a Task that takes arguments from the command line, use the `--arguments`
option, passing arguments as a set of \<key>:\<value> pairs:

```sh-session
bundle exec maintenance_tasks perform Maintenance::ParamsTask \
  --arguments post_ids:1,2,3 content:"Hello, World!"
```

#### Running a Task from Ruby

You can also run a Task in Ruby by sending `run` with a Task name to Runner:

```ruby
MaintenanceTasks::Runner.run(name: "Maintenance::UpdatePostsTask")
```

To run a Task that processes CSVs using the Runner, provide a Hash containing an
open IO object and a filename to `run`:

```ruby
MaintenanceTasks::Runner.run(
  name: "Maintenance::ImportPostsTask",
  csv_file: { io: File.open("path/to/my_csv.csv"), filename: "my_csv.csv" }
)
```

To run a Task that takes arguments using the Runner, provide a Hash containing
the set of arguments (`{ parameter_name: argument_value }`) to `run`:

```ruby
MaintenanceTasks::Runner.run(
  name: "Maintenance::ParamsTask",
  arguments: { post_ids: "1,2,3" }
)
```

### Monitoring your Task’s status

The web UI will provide updates on the status of your Task. Here are the states
a Task can be in:

* **new**: A Task that has not yet been run.
* **enqueued**: A Task that is waiting to be performed after a user has
  instructed it to run.
* **running**: A Task that is currently being performed by a job worker.
* **pausing**: A Task that was paused by a user, but needs to finish work before
  stopping.
* **paused**: A Task that was paused by a user and is not performing. It can be
  resumed.
* **interrupted**: A Task that has been momentarily interrupted by the job
  infrastructure.
* **cancelling**: A Task that was cancelled by a user, but needs to finish work
  before stopping.
* **cancelled**: A Task that was cancelled by a user and is not performing. It
  cannot be resumed.
* **succeeded**: A Task that finished successfully.
* **errored**: A Task that encountered an unhandled exception while performing.

### Using Maintenance Tasks in API-only applications

The Maintenance Tasks engine uses Rails sessions for flash messages and storing
the CSRF token. For the engine to work in an API-only Rails application, you
need to add a [session middleware][] and the `ActionDispatch::Flash` middleware.
The engine also defines a strict [Content Security Policy][], make sure to
include `ActionDispatch::ContentSecurityPolicy::Middleware` in your app's
middleware stack to ensure the CSP is delivered to the user's browser.

[session middleware]: https://guides.rubyonrails.org/api_app.html#using-session-middlewares
[Content Security Policy]: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP

Configuring Rails applications is beyond the scope of this documentation, but
one way to do this is to add these lines to your application configuration:

```ruby
# config/application.rb
module YourApplication
  class Application < Rails::Application
    # ...
    config.api_only = true

    config.middleware.insert_before ::Rack::Head, ::ActionDispatch::Flash
    config.middleware.insert_before ::Rack::Head, ::ActionDispatch::ContentSecurityPolicy::Middleware
    config.session_store :cookie_store, key: "_#{railtie_name.chomp("_application")}_session", secure: true
    config.middleware.insert_before ::ActionDispatch::Flash, config.session_store, config.session_options
    config.middleware.insert_before config.session_store, ActionDispatch::Cookies
  end
end
```

You can read more in the [Using Rails for API-only Applications][rails api]
Rails guide.

[rails api]: https://guides.rubyonrails.org/api_app.html

### How Maintenance Tasks runs a Task

Maintenance tasks can be running for a long time, and the purpose of the gem is
to make it easy to continue running tasks through deploys, [Kubernetes Pod
scheduling][k8s-scheduling], [Heroku dyno restarts][heroku-cycles] or other
infrastructure or code changes.

[k8s-scheduling]: https://kubernetes.io/docs/concepts/scheduling-eviction/
[heroku-cycles]: https://www.heroku.com/dynos/lifecycle

This means a Task can safely be interrupted, re-enqueued and resumed without any
intervention at the end of an iteration, after the `process` method returns.

By default, a running Task will be interrupted after running for more than 5
minutes. This is [configured in the `job-iteration` gem][max-job-runtime] and
can be tweaked in an initializer if necessary.

[max-job-runtime]: https://github.com/Shopify/job-iteration/blob/-/guides/best-practices.md#max-job-runtime

Running tasks will also be interrupted and re-enqueued when needed. For example
[when Sidekiq workers shut down for a deploy][sidekiq-deploy]:

[sidekiq-deploy]: https://github.com/mperham/sidekiq/wiki/Deployment

* When Sidekiq receives a TSTP or TERM signal, it will consider itself to be
  stopping.
* When Sidekiq is stopping, JobIteration stops iterating over the enumerator.
  The position in the iteration is saved, a new job is enqueued to resume work,
  and the Task is marked as interrupted.

When Sidekiq is stopping, it will give workers 25 seconds to finish before
forcefully terminating them (this is the default but can be configured with the
`--timeout` option). Before the worker threads are terminated, Sidekiq will try
to re-enqueue the job so your Task will be resumed. However, the position in the
collection won’t be persisted so at least one iteration may run again.

Job queues other than Sidekiq may handle this in different ways.

#### Help! My Task is stuck

If the queue adapter configured for your application doesn’t have this property,
or if Sidekiq crashes, is forcefully terminated, or is unable to re-enqueue the
jobs that were in progress, the Task may be in a seemingly stuck situation where
it appears to be running but is not. In that situation, pausing or cancelling it
will not result in the Task being paused or cancelled, as the Task will get
stuck in a state of `pausing` or `cancelling`. As a work-around, if a Task is
`cancelling` for more than 5 minutes, you can cancel it again. It will then be
marked as fully cancelled, allowing you to run it again.

If you are stuck in `pausing` and wish to preserve your tasks's position
(instead of cancelling and rerunning), you may click "Force pause".

### Configuring the gem

There are a few configurable options for the gem. Custom configurations should
be placed in a `maintenance_tasks.rb` initializer.

#### Reporting errors

Exceptions raised while a Task is performing are rescued and information about
the error is persisted and visible in the UI.

Errors are also sent to the `Rails.error.reporter`, which can be configured by
your application. See the [Error Reporting in Rails
Applications][rails-error-reporting] guide for more details.

Reports to the error reporter will contain the following data:

* `error`: The exception that was raised.
* `context`: A hash with additional information about the Task and the error:
   * `task_name`: The name of the Task that errored
   * `started_at`: The time the Task started
   * `ended_at`: The time the Task errored
   * `run_id`: The id of the errored Task run
   * `tick_count`: The tick count at the time of the error
   * `errored_element`: The element, if any, that was being processed when the
* `source`: This will be `maintenance-tasks`

Note that `context` may be empty if the Task produced an error before any
context could be gathered (for example, if deserializing the job to process your
Task failed).

Here's an example custom subscriber to the Rails error reporter for integrating
with an exception monitoring service (Bugsnag):

```ruby
# config/initializers/maintenance_tasks.rb

class MaintenanceTasksErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    return unless source == "maintenance-tasks"

    Bugsnag.notify(error) do |notification|
      notification.add_metadata(:task, context)
    end
  end
end

Rails.error.subscribe(MaintenanceTasksErrorSubscriber.new)
```

#### Reporting errors during iteration

By default, errors raised during task iteration will be raised to the
application and iteration will stop. However, you may want to handle some errors
and continue iteration. `MaintenanceTasks::Task.report_on` can be used to rescue
certain exceptions and report them to the Rails error reporter. Any keyword
arguments are passed to
[ActiveSupport::ErrorReporter#report][as-error-reporter-report]:

[as-error-reporter-report]: https://api.rubyonrails.org/classes/ActiveSupport/ErrorReporter.html#method-i-report

```ruby
class MyTask < MaintenanceTasks::Task
  report_on(MyException, OtherException, severity: :info, context: {task_name: "my_task"})
end
```

`MaintenanceTasks::Task` also includes `ActiveSupport::Rescuable` which you can
use to implement custom error handling.

```ruby
class MyTask < MaintenanceTasks::Task
  rescue_from(MyException) do |exception|
    handle(exception)
  end
end
```

#### Customizing the maintenance tasks module

`MaintenanceTasks.tasks_module` can be configured to define the module in which
tasks will be placed.

```ruby
# config/initializers/maintenance_tasks.rb

MaintenanceTasks.tasks_module = "TaskModule"
```

If no value is specified, it will default to `Maintenance`.

#### Organizing tasks using namespaces

Tasks may be nested arbitrarily deeply under `app/tasks/maintenance`, for
example given a task file
`app/tasks/maintenance/team_name/service_name/update_posts_task.rb` we can
define the task as:

```ruby
module Maintenance
  module TeamName
    module ServiceName
      class UpdatePostsTask < MaintenanceTasks::Task
        def process(rows)
          # ...
        end
      end
    end
  end
end
```

#### Customizing the underlying job class

`MaintenanceTasks.job` can be configured to define a Job class for your tasks to
use. This is a global configuration, so this Job class will be used across all
maintenance tasks in your application.

```ruby
# config/initializers/maintenance_tasks.rb

MaintenanceTasks.job = "CustomTaskJob"

# app/jobs/custom_task_job.rb

class CustomTaskJob < MaintenanceTasks::TaskJob
  queue_as :low_priority
end
```

The Job class **must inherit** from `MaintenanceTasks::TaskJob`.

Note that `retry_on` is not supported for custom Job classes, so failed jobs
cannot be retried.

#### Customizing the rate at which task progress gets updated

`MaintenanceTasks.ticker_delay` can be configured to customize how frequently
task progress gets persisted to the database. It can be a `Numeric` value or an
`ActiveSupport::Duration` value.

```ruby
# config/initializers/maintenance_tasks.rb

MaintenanceTasks.ticker_delay = 2.seconds
```

If no value is specified, it will default to 1 second.

#### Customizing which Active Storage service to use

The Active Storage framework in Rails 6.1 and up supports multiple storage
services. To specify which service to use,
`MaintenanceTasks.active_storage_service` can be configured with the service’s
key, as specified in your application’s `config/storage.yml`:

```yaml
# config/storage.yml

user_data:
  service: GCS
  credentials: <%= Rails.root.join("path/to/user/data/keyfile.json") %>
  project: "my-project"
  bucket: "user-data-bucket"

internal:
  service: GCS
  credentials: <%= Rails.root.join("path/to/internal/keyfile.json") %>
  project: "my-project"
  bucket: "internal-bucket"
```

```ruby
# config/initializers/maintenance_tasks.rb

MaintenanceTasks.active_storage_service = :internal
```

There is no need to configure this option if your application uses only one
storage service. `Rails.configuration.active_storage.service` is used by
default.

#### Customizing the backtrace cleaner

`MaintenanceTasks.backtrace_cleaner` can be configured to specify a backtrace
cleaner to use when a Task errors and the backtrace is cleaned and persisted. An
`ActiveSupport::BacktraceCleaner` should be used.

```ruby
# config/initializers/maintenance_tasks.rb

cleaner = ActiveSupport::BacktraceCleaner.new
cleaner.add_silencer { |line| line =~ /ignore_this_dir/ }

MaintenanceTasks.backtrace_cleaner = cleaner
```

If none is specified, the default `Rails.backtrace_cleaner` will be used to
clean backtraces.

#### Customizing the parent controller for the web UI

`MaintenanceTasks.parent_controller` can be configured to specify a controller
class for all of the web UI engine's controllers to inherit from.

This allows applications with common logic in their `ApplicationController` (or
any other controller) to optionally configure the web UI to inherit that logic
with a simple assignment in the initializer.

```ruby
# config/initializers/maintenance_tasks.rb

MaintenanceTasks.parent_controller = "Services::CustomController"

# app/controllers/services/custom_controller.rb

class Services::CustomController < ActionController::Base
  include CustomSecurityThings
  include CustomLoggingThings
  # ...
end
```

The parent controller value **must** be a string corresponding to an existing
controller class which **must inherit** from `ActionController::Base`.

If no value is specified, it will default to `"ActionController::Base"`.

#### Configure time after which the task will be considered stuck

To specify a time duration after which a task is considered stuck if it has not
been updated, you can configure `MaintenanceTasks.stuck_task_duration`. This
duration should account for job infrastructure events that may prevent the
maintenance tasks job from being executed and cancelling the task.

The value for `MaintenanceTasks.stuck_task_duration` must be an
`ActiveSupport::Duration`. If no value is specified, it will default to 5
minutes.

#### Configure status reload frequency

`MaintenanceTasks.status_reload_frequency` can be configured to specify how often
the run status should be reloaded during iteration. By default, the status is
reloaded every second, but this can be increased to improve performance. Note that increasing the reload interval impacts how quickly
your task will stop if it is paused or interrupted.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.status_reload_frequency = 10.seconds  # Reload status every 10 seconds
```

Individual tasks can also override this setting using the `reload_status_every` method:

```ruby
# app/tasks/maintenance/update_posts_task.rb

module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    # Reload status every 5 seconds instead of the global default
    reload_status_every(5.seconds)

    def collection
      Post.all
    end

    def process(post)
      post.update!(content: "New content!")
    end
  end
end
```

This optimization can significantly reduce database queries, especially for short iterations.
This is especially useful if the task doesn't need to check for cancellation/pausing very often.

#### Metadata

`MaintenanceTasks.metadata` can be configured to specify a proc from which to
get extra information about the run. Since this proc will be ran in the context
of the `MaintenanceTasks.parent_controller`, it can be used to keep the id or
email of the user who performed the maintenance task.

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.metadata = ->() do
  { user_email: current_user.email }
end
```

## Upgrading

Use bundler to check for and upgrade to newer versions. After installing a new
version, re-run the install command:

```sh-session
bin/rails generate maintenance_tasks:install
```

This ensures that new migrations are installed and run as well.

### What if I’ve deleted my previous Maintenance Task migrations?

The install command will attempt to reinstall these old migrations and migrating
the database will cause problems. Use `bin/rails
maintenance_tasks:install:migrations` to copy the gem’s migrations to your
`db/migrate` folder. Check the release notes to see if any new migrations were
added since your last gem upgrade. Ensure that these are kept, but remove any
migrations that already ran.

Run the migrations using `bin/rails db:migrate`.

## Contributing

Would you like to report an issue or contribute with code? We accept issues and
pull requests. You can find the contribution guidelines on
[CONTRIBUTING.md][contributing].

[contributing]: https://github.com/Shopify/maintenance_tasks/blob/main/.github/CONTRIBUTING.md

## Releasing new versions

Updates should be added to the latest draft release on GitHub as Pull Requests
are merged.

Once a release is ready, follow these steps:

* Update `spec.version` in `maintenance_tasks.gemspec`.
* Run `bundle install` to bump the `Gemfile.lock` version of the gem.
* Open a PR and merge on approval.
* Deploy via [Shipit][shipit] and see the new version on
  <https://rubygems.org/gems/maintenance_tasks>.
* Ensure the release has documented all changes and publish it.
* Create a new [draft release on GitHub][release] with the title “Upcoming
  Release”. The tag version can be left blank. This will be the starting point
  for documenting changes related to the next release.

[release]: https://help.github.com/articles/creating-releases/
[shipit]: https://shipit.shopify.io/shopify/maintenance_tasks/rubygems
