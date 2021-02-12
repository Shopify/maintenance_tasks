# MaintenanceTasks

A Rails engine for queuing and managing maintenance tasks.

## Table of Contents

* [Demo](#demo)
* [Installation](#installation)
  * [Active Job Dependency](#active-job-dependency)
* [Usage](#usage)
  * [Creating a Task](#creating-a-task)
  * [Creating a CSV Task](#creating-a-csv-task)
  * [Creating a custom Task](#creating-a-custom-task)
  * [Considerations when writing Tasks](#considerations-when-writing-tasks)
  * [Writing tests for a Task](#writing-tests-for-a-task)
  * [Writing tests for a CSV Task](#writing-tests-for-a-csv-task)
  * [Writing tests for a custom Task](#writing-tests-for-a-custom-task)
  * [Running a Task](#running-a-task)
  * [Monitoring your Task's status](#monitoring-your-tasks-status)
  * [How Maintenance Tasks runs a Task](#how-maintenance-tasks-runs-a-task)
    * [Help! My Task is stuck](#help-my-task-is-stuck)
  * [Configuring the gem](#configuring-the-gem)
    * [Customizing the error handler](#customizing-the-error-handler)
    * [Customizing the maintenance tasks module](#customizing-the-maintenance-tasks-module)
    * [Customizing the underlying job class](#customizing-the-underlying-job-class)
    * [Customizing the rate at which task progress gets updated](#customizing-the-rate-at-which-task-progress-gets-updated)
* [Upgrading](#upgrading)
* [Contributing](#contributing)
* [Releasing new versions](#releasing-new-versions)

## Demo

Watch this demo video to see the gem in action:

[![Link to demo video](static/demo.png)](https://www.youtube.com/watch?v=BTuvTQxlFzs)

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

The generator creates and runs a migration to add the necessary table to your
database. It also mounts Maintenance Tasks in your `config/routes.rb`. By
default the web UI can be accessed in the new `/maintenance_tasks` path.

In case you use an exception reporting service (e.g. Bugsnag) you might want to
define an error handler. See [Customizing the error
handler](#customizing-the-error-handler) for more information.

### Active Job Dependency

The Maintenance Tasks framework relies on ActiveJob behind the scenes to run
Tasks. The default queuing backend for ActiveJob is
[asynchronous][async-adapter]. It is **strongly recommended** to change this to
a persistent backend so that Task progress is not lost during code or
infrastructure changes. For more information on configuring a queuing backend,
take a look at the [ActiveJob documentation][active-job-docs].

[async-adapter]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/AsyncAdapter.html
[active-job-docs]: https://guides.rubyonrails.org/active_job_basics.html#setting-the-backend

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

### Creating a CSV Task

You can also write a Task that iterates on a CSV file. Note that writing CSV
Tasks **requires ActiveStorage to be configured**. Ensure that the dependency
is specified in your application's Gemfile, and that you've followed the
[setup instuctions][setup].

[setup]: https://edgeguides.rubyonrails.org/active_storage_overview.html#setup

Generate a CSV Task by running:

```bash
$ rails generate maintenance_tasks:task import_posts --csv
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

```csv
# posts.csv
title,content
My Title,Hello World!
```

### Creating a custom Task

TODO: Add generation instructions

If you have a special use case requiring iteration over an unsupported collection type, such as external resources fetched from some API, you can implement the `enumerator_builder` method instead.

This method should return an object responding to `enumerator(context:)` with an Enumerator, yielding pairs of `[item, item_cursor]`. In order for your enumerator to support resuming iteration part way through, you may use the `context.cursor`.

You may optionally provide an implementation for `count`, if appropriate.

```ruby
# app/tasks/maintenance/shopping_list_task.rb
module Maintenance
  class ShoppingListTask < MaintenanceTasks::Task
    def enumerator_builder
      IngredientsEnumerator.new
    end

    def process(ingredient)
      ShoppingList.add(ingredient)
    end

    class IngredientEnumerator
      def enumerator(context:)
        Enumerator.new do |yielder|
          cursor = context.cursor

          if cursor.nil?
            recipe = FancyRecipeAPI.random_recipe
            ingredient_id = nil
          else
            recipe_id, ingredient_id = cursor.split(':', 2)
            recipe = FancyRecipeAPI.recipe(recipe_id)
          end

          loop do
            page = if ingredient_id.nil?
              FancyRecipeAPI
                .paginated_ingredients(recipe.id, max: 5)
            else
              FancyRecipeAPI
                .paginated_ingredients(recipe.id, max: 5, after: ingredient_id)
            end

            page.entries.each do |ingredient|
              ingredient_id = ingredient.id
              cursor = "#{recipe.id}:#{ingredient.id}"

              yielder.yield([ingredient, cursor])
            end

            break unless page.has_next?
          end
        end
      end
    end
  end
end
```

In some cases, you may have no use for a cursor (e.g. iterating over some collection until it is empty), in which case your Enumerator may yield `nil` cursors (i.e. pairs of `[item, nil]`).

```ruby
# app/tasks/maintenance/ingredient_purge_task.rb
module Maintenance
  class IngredientPurgeTask < MaintenanceTasks::Task
    def enumerator_builder
      ExpiredIngredientsEnumerator.new
    end

    def count
      PantryAPI.ingredients(expired: true).count +
        FridgeAPI.ingredients(expired: true).count +
        FreezerAPI.ingredients(expired: true).count
    end

    def process(ingredient)
      ingredient.compost!
    end

    class ExpiredIngredientsEnumerator
      def enumerator(*)
        Enumerator.chain(
          PantryAPI.ingredients(expired: true).auto_paginate,
          FridgeAPI.ingredients(expired: true).auto_paginate,
          FreezerAPI.ingredients(expired: true).auto_paginate,
        ).lazy.map { |ingredient| [ingredient, nil] }
      end
    end
  end
end
```

### Considerations when writing Tasks

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

### Writing tests for a Task

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

      Maintenance::UpdatePostsTask.process(post)

      assert_equal 'New content!', post.content
    end
  end
end
```

### Writing tests for a CSV Task

You should write tests for your `#process` method in a CSV Task as well. It
takes a `CSV::Row` as an argument. You can pass a row, or a hash with string
keys to `#process` from your test.

```ruby
# app/tasks/maintenance/import_posts_task_test.rb
module Maintenance
  class ImportPostsTaskTest < ActiveSupport::TestCase
    test "#process performs a task iteration" do
      assert_difference -> { Post.count } do
        Maintenance::UpdatePostsTask.process({
          'title' => 'My Title',
          'content' => 'Hello World!',
        })
      end

      post = Post.last
      assert_equal 'My Title', post.title
      assert_equal 'Hello World!', post.content
    end
  end
end
```

### Writing test for a custom Task

As with other tasks, you should write tests for your `#process` method. It will receive the first item in each pair your custom Enumerator yields (`[item, item_cursor]`).

You should also ensure your Enumerator is tested, by unit testing it in isolation, testing your `#enumerator_builder` method, or both. Make sure you test how your Enumerator handles the absence or presence of a `context.cursor`, if applicable.

```ruby
# test/tasks/maintenance/shopping_list_task_test.rb
module Maintenance
  class ShoppingListTaskTest < ActiveSupport::TestCase
    test '#process adds ingredients to the shopping list' do
      ingredient = recipes(:tacos).first
      ShoppingList.expects(:add).with(ingredient)

      ShoppingListTask.process(ingredient)
    end

    test '#enumerator_builder.enumerator enumerates ingredients for a random recipe' do
      FancyRecipeApi.fake_it_till_you_make_it do
        recipe = recipes(:tacos)
        FancyRecipeAPI.expects(:random_recipe).returns(recipe)

        expected_ingredient_pairs = ingredient_pairs(recipe)

        context = stub('context', cursor: nil)
        actual_ingredient_pairs = ShoppingListTask.enumerator_builder
          .enumerator(context: context).to_a

        assert_equal expected_ingredient_pairs, actual_ingredient_pairs
      end
    end

    test '#enumerator_builder.enumerator enumerates remaining ingredients for the cursor recipe' do
      FancyRecipeApi.fake_it_till_you_make_it do
        expected_ingredient_pairs = ingredient_pairs(recipes(:vegan_tacos))
        ingredients_so_far = expected_ingredient_pairs.shift(3)
        cursor = ingredients_so_far.last.last

        context = stub('context', cursor: cursor)
        actual_ingredient_pairs = ShoppingListTask.enumerator_builder
          .enumerator(context: context).to_a

        assert_equal expected_ingredient_pairs, actual_ingredient_pairs
      end
    end

    test '#count returns nil, as we cannot guess the recipe choice' do
      assert_nil ShoppingListTask.count
    end

    private

    def ingredient_pairs(recipe)
      recipe.ingredients.map do |ingredient|
        cursor = "#{recipe.id}:#{ingredient.id}"
        [ingredient, cursor]
      end
    end
  end
end
```

Dependaing on its complexity, you may choose to test your Enumerator builder in
isolation, in which case you can simplify the tests for your Task.

```ruby
# test/tasks/maintenance/ingredient_purge_task_test.rb
module Maintenance
  class IngredientPurgeTaskTest < ActiveSupport::TestCase
    test '#process composts ingredients' do
      ingredient = ingredients(:tomato)
      ingredient.expects(:compost!)

      IngredientPurgeTask.process(ingredient)
    end

    test '#enumerator_builder returns an ExpiredIngredientsEnumerator' do
      assert_instance_of(
        ExpiredIngredientsEnumerator,
        IngredientPurgeTask.enumerator_builder,
      )
    end
  end
end
```

```ruby
# test/models/expired_ingredients_enumerator_test.rb
class ExpiredIngredientsEnumeratorTest < ActiveSupport::TestCase
  setup do
    [PantryAPI, FridgeAPI, FreezerAPI].each(&:enable_test_mode!)
  end

  teardown do
    [PantryAPI, FridgeAPI, FreezerAPI].each(&:disable_test_mode!)
  end

  test '#enumerator enumerates expired ingredients, ignoring cursor' do
    expirees = []

    PantryAPI.stock(ingredients(:fresh_tomatoes))

    ingredients(:green_potatoes).tap do |ingredient|
      PantryAPI.stock(ingredient)
      expirees << ingredient
    end

    ingredients(:curdled_milk).tap do |ingredient|
      FridgeAPI.stock(ingredient)
      expirees << ingredient
    end

    FridgeAPI.stock(ingredients(:leftover_pizza))

    ingredients(
      :entire_pack_of_strawberries_ruined_by_that_single_one_that_had_mold,
    ).tap do |ingredient|
      FridgeAPI.stock(ingredient)
      expirees << ingredient
    end

    ingredients(:mysterious_container).tap do |ingredient|
      FreezerAPI.stock(ingredient)
      expirees << ingredient
    end

    FreezerAPI.stock(ingredients(:ice_cubes))

    expected_pairs = expirees.map do |ingredient|
      cursor = nil
      [ingredient, cursor]
    end

    context = stub('context')
    context.expects(:cursor).never

    actual_pairs =
      ExpiredIngredientsEnumerator.enumerator(context: context).to_a

    assert_equal expected_pairs, actual_pairs
  end

  test '#enumerator is empty if no expired ingredients' do
    PantryAPI.stock(ingredients(:tortillas))

    assert_empty ExpiredIngredientsEnumerator.enumerator(context: context).to_a
  end
end
```

</details>

### Running a Task

You can run your new Task by accessing the Web UI and clicking on "Run".

Alternatively, you can run your Task in the command line:

```bash
$ bundle exec maintenance_tasks perform Maintenance::UpdatePostsTask
```

You can also run a Task in Ruby by sending `run` with a Task name to Runner:

```ruby
MaintenanceTasks::Runner.run(name: 'Maintenance::UpdatePostsTask')
```

### Monitoring your Task's status

The web UI will provide updates on the status of your Task. Here are the states
a Task can be in:

* **new**: A Task that has not yet been run.
* **enqueued**: A Task that is waiting to be performed after a user has
  instructed it to run.
* **running**: A Task that is currently being performed by a job worker.
* **pausing**: A Task that was paused by a user, but needs to finish work
  before stopping.
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

#### Help! My Task is stuck

Finally, if the queue adapter configured for your application doesn't have this
property, or if Sidekiq crashes, is forcefully terminated, or is unable to
re-enqueue the jobs that were in progress, the Task may be in a seemingly stuck
situation where it appears to be running but is not. In that situation, pausing
or cancelling it will not result in the Task being paused or cancelled, as the
Task will get stuck in a state of `pausing` or `cancelling`. As a work-around,
if a Task is `cancelling` for more than 5 minutes, you will be able to cancel it
for good, which will just mark it as cancelled, allowing you to run it again.

### Configuring the gem

There are a few configurable options for the gem. Custom configurations should
be placed in a `maintenance_tasks.rb` initializer.

#### Customizing the error handler

Exceptions raised while a Task is performing are rescued and information about
the error is persisted and visible in the UI.

If you want to integrate with an exception monitoring service (e.g. Bugsnag),
you can define an error handler:

```ruby
# config/initializers/maintenance_tasks.rb
MaintenanceTasks.error_handler = ->(error) { Bugsnag.notify(error) }
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
  <https://rubygems.org/gems/maintenance_tasks>.

[release]: https://help.github.com/articles/creating-releases/
[shipit]: https://shipit.shopify.io/shopify/maintenance_tasks/rubygems
