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

Or subclass your ApplicationTask and implement:

* `collection`: return an Active Record Relation or an Array to be iterated
  over.
* `task_iteration`: do the work of your maintenance task on a single record
* `task_count`: return the number of rows that will be iterated over (optional,
  to be able to show progress)

### Example

```ruby
# app/tasks/maintenance/update_posts_task.rb
module Maintenance
  class UpdatePostsTask < ApplicationTask
    def collection
      Post.all
    end

    def task_count
      collection.count
    end

    def task_iteration(post)
      post.update!(content: 'New content!')
    end
  end
end
```
