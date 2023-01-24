# Contributing

Before engaging with this community, please read and understand our
[Code of Conduct](https://github.com/Shopify/maintenance_tasks/blob/main/.github/CODE_OF_CONDUCT.md).

## Issue Reporting

* Check to make sure the same issue has not already been reported or fixed.
* Open an issue with a descriptive title and summary.
* Be clear and concise and provide as many details as possible (e.g. Maintenance
  Tasks version, Ruby version, Rails version, etc.)
* Include relevant code, where necessary.

## Setting up development environment

* The gem follows standard Rails practices:
  * `bundle install` to install dependencies
  * `bin/rails server` to start the server
  * `bin/rails test` to run tests
  * `bin/rails test:system` to run system tests
* You can also use `bundle exec rake` to run all the tests and the linter.

## Pull Requests

* Make sure tests are added for any changes to the code.
* Make sure classes and public methods are documented appropriately with
  [YARD](https://yardoc.org).
* Squash related commits together.
* Open a pull request once the change is ready to be reviewed.
* Include release notes describing the potential impact of the change in the
  pull request.
