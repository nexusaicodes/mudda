
# Style

We aim to write code that is a pleasure to read, and we have a lot of opinions about how to do it well. Writing great code is an essential part of our programming culture, and we deliberately set a high bar for every code change anyone contributes. We care about how code reads, how code looks, and how code makes you feel when you read it.

We love discussing code. If you have questions about how to write something, or if you detect some smell you are not quite sure how to solve, please ask away to other programmers. A Pull Request is a great way to do this.

When writing new code, unless you are very familiar with our approach, try to find similar code elsewhere to look for inspiration.

## Conditional returns

In general, we prefer to use expanded conditionals over guard clauses.

```ruby
# Bad
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids
  @bucket.recordings.todos.find(ids.split(","))
end

# Good
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

This is because guard clauses can be hard to read, especially when they are nested.

As an exception, we sometimes use guard clauses to return early from a method:

* When the return is right at the beginning of the method.
* When the main method body is not trivial and involves several lines of code.

```ruby
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

## Methods ordering

We order methods in classes in the following order:

1. `class` methods
2. `public` methods with `initialize` at the top.
3. `private` methods

## Invocation order

We order methods vertically based on their invocation order. This helps us to understand the flow of the code.

```ruby
class SomeClass
  def some_method
    method_1
    method_2
  end

  private
    def method_1
      method_1_1
      method_1_2
    end
  
    def method_1_1
      # ...
    end
  
    def method_1_2
      # ...
    end
  
    def method_2
      method_2_1
      method_2_2
    end
  
    def method_2_1
      # ...
    end
  
    def method_2_2
      # ...
    end
end
```

## To bang or not to bang

Should I call a method `do_something` or `do_something!`?

As a general rule, we only use `!` for methods that have a correspondent counterpart without `!`. In particular, we don’t use `!` to flag destructive actions. There are plenty of destructive methods in Ruby and Rails that do not end with `!`.

## Visibility modifiers

We don't add a newline under visibility modifiers, and we indent the content under them.

```ruby
class SomeClass
  def some_method
    # ...
  end

  private
    def some_private_method_1
      # ...
    end

    def some_private_method_2
      # ...
    end
end
```

If a module only has private methods, we mark it `private` at the top and add an extra new line after but don't indent.

```ruby
module SomeModule
  private
  
  def some_private_method
    # ...
  end
end
```

## CRUD controllers

We model web endpoints as CRUD operations on resources (REST). When an action doesn't map cleanly to a standard CRUD verb, we introduce a new resource rather than adding custom actions.

```ruby
# Bad
resources :cards do
  post :pin
  post :unpin
end

# Good
resources :cards do
  resource :pin, only: %i[ create destroy ]
end
```

## Controller and model interactions

In general, we favor a vanilla Rails approach with thin controllers directly invoking a rich domain model. We don't use services or other artifacts to connect the two.

Invoking plain Active Record operations is totally fine:

```ruby
class Cards::NotesController < ApplicationController
  def create
    @note = @card.notes.create!(note_params)
  end
end
```

For more complex behavior, we prefer clear, intention-revealing model APIs that controllers call directly:

```ruby
class Cards::PinsController < ApplicationController
  def create
    @card.pin
  end
end
```

When justified, it is fine to use services or form objects, but don't treat those as special artifacts:

```ruby
OwnerPassword.authenticate(email_address, password)
```

## Run async operations in jobs

As a general rule, we write shallow job classes that delegate the logic itself to domain models:

* We typically use the suffix `_later` to flag methods that enqueue a job.
* A common scenario is having a model class that enqueues a job that, when executed, invokes some method in that same class. In this case, we use the suffix `_now` for the regular synchronous method.

An illustration (Mudda has no event relaying):

```ruby
module Event::Relaying
  extend ActiveSupport::Concern

  included do
    after_create_commit :relay_later
  end

  def relay_later
    Event::RelayJob.perform_later(self)
  end

  def relay_now
    # ...
  end
end

class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

## Logging and errors

Logs are structured events, not prose. `lib/structured_log.rb` turns every `Rails.event`
notification, the framework's own included, into one line: JSON in production
(`RAILS_LOG_FORMAT`), readable `event key=value` text locally. `RAILS_LOG_LEVEL` decides what
is written, and production runs at `warn`.

```ruby
# Bad
Rails.logger.error "WebhookDelivery #{event_id} abandoned: #{error}"

# Good
StructuredLog.error("board.delivery.abandoned", event_id: event_id, attempts: attempts, last_error: error)
```

- **Name events `domain.object.outcome`**: `board.delivery.abandoned`, `auth.signin.failed`,
  `mcp.request.completed`, `rate_limit.hit`.
- **Pick the level by what it means.** `error`: a user's work lost or blocked, or a bug. `warn`:
  degraded but handled, such as a failure that will be retried, a refused credential or
  signature, a rate-limit hit. `info`: a normal milestone, dropped in production, so anything
  that must be kept is written to the database (an `Event`, a delivery's `last_error`).
  `debug`: diagnostics.
- **Context comes for free.** Every line in a request carries `request_id`, and once a session
  is known, `account_id`, `user_id`, `session_kind` and, for a token, `agent_name`. Every line in
  a job carries `job_id`, `job` and the enqueuing request's `request_id` (`lib/job_context.rb`).
  Don't repeat them in the payload.
- **Never log a secret or PII.** No passwords, tokens, OAuth `code`/`code_verifier`, signatures
  or webhook secrets. Mask emails with `StructuredLog.mask_email`. Job arguments are never logged.
  Request parameters, redirects and span URLs are filtered by `config.filter_parameters` and
  `filter_redirect` (`config/initializers/filter_parameter_logging.rb`); a new credential
  parameter is added there, and a query string bound for a log or span goes through
  `StructuredLog.filter_query`.
- **Spans follow the same rules.** Tracing is opt-in (`config/initializers/opentelemetry.rb`,
  inert unless `OTEL_*` is set), so code never assumes it: wrap a domain operation in
  `StructuredLog.in_span("domain.operation", { "mudda.thing.id" => id })`, which yields the
  span or `nil`. Attributes are ids, kinds and outcomes, never what a user wrote (card text,
  search terms, tool arguments). SQL spans carry obfuscated statements only.

Errors follow one contract:

- **Classify before handling.** A client's mistake (validation, not found, a refused
  credential, a rate limit) is a precise 4xx in the `JsonErrors` envelope and is never reported.
  A dependency failure (the platform's webhook endpoint) is retried, logged at `warn` per
  attempt, and reported at `error` once attempts run out. Anything else is a bug: a 500, reported
  through `Rails.error`, whose `request_id` is the reference the user sees.
- **Rescue narrowly; report at the boundary.** Inner code raises. `rescue StandardError` belongs
  only at a boundary (a controller, a job, a middleware, an after-commit callback whose write
  already happened), and a boundary rescue calls `Rails.error.report`, which logs one
  `error.reported` line. Don't also log the same failure.
- **Every error response carries the request id**: `request_id` in the JSON envelope, a
  bilingual "Reference" on the HTML error pages (`JsonPublicExceptions`), and in MCP results.
- **Test what is reported**, with `assert_error_reported`, `assert_no_error_reported` and
  `assert_event_reported`, never by reading the log.
