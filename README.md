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

* `task_enumerator`: return an Enumerator over your records
* `task_iteration`: do the work of your maintenance task on a single record
* `task_count`: return the number of rows that will be iterated over (optional,
  to be able to show progress)

### Example

```ruby
# app/jobs/maintenance/sleepy_task.rb
module Maintenance
  class SleepyTask < ApplicationTask
    class RandomError < StandardError
    end

    # TODO: provide these
    # queue_as :maintenance
    # queue_with_priority 100
    # retry_on RuntimeError

    def task_enumerator(cursor:)
      enum = (1..100).to_enum.lazy.with_index
      return enum unless cursor
      enum.drop(cursor + 1)
    end

    def task_iteration(number)
      Rails.logger.info "Iteration ##{number} started"
      sleep 1
      raise RandomError, "bad luck" if rand(10).zero?
      Rails.logger.info "Iteration ##{number} ended"
    end

    def task_count
      100
    end
  end
end
```
