# Airbrake Client

Capture exceptions and post notices for them to [Airbrake](http://airbrake.io)
or to your [Errbit](http://errbit.com/) installation.

This library was originally forked from the
[`airbrake`](https://hex.pm/packages/airbrake) Hex package.  Development and
support for that library seems to have lapsed, but we (the devs at Euna Payments
(formerly CityBase)) had changes and updates we wanted to make.  So we decided
to publish our own fork of the library.

[Documentation is available on
hexdocs.pm](https://hexdocs.pm/airbrake_client/readme.html).

There are sections below for configuration and usage of this library. Some other
documentation that might be interesting:

* Testing with `Airbrake.Test` in your app.
* [Development notes](developing.html)
* [Migrating from `airbrake`](migrating.html)

## Installation

Add `airbrake_client` to your dependencies:

```elixir
defp deps do
  [
    {:airbrake_client, "~> 2.3"}
  ]
end
```


## Configuration

See the ["Create notice
v3"](https://docs.airbrake.io/docs/devops-tools/api/#create-notice-v3) section
in the Airbrake API docs to understand the config options.

Configure `:airbrake_client` in your `config/*.exs` files.

Only the `:api_key` and `:project_id` options are required.

### Airbrake project configuration

These options configure `:airbrake_client` to connect to the right project on
Airbrake.io (or another host).

```elixir
config :airbrake_client,
  api_key: System.get_env("AIRBRAKE_API_KEY"),
  project_id: System.get_env("AIRBRAKE_PROJECT_ID"),
  host: "https://api.airbrake.io"
```

* `:api_key` - (**required**, binary) the token needed to access the [Airbrake
  API](https://airbrake.io/docs/api/). You can find it in [User
  Settings](https://airbrake.io/users/edit).
* `:project_id` - (**required**, integer or string) the id of your project at
  Airbrake.
* `:host` - (string) the URL of the HTTP host; defaults to
  `https://api.airbrake.io`.

### Data for an Airbrake notice

You can add some static data to every posted notice:

```elixir
config :airbrake_client,
  # ...
  context_environment: System.get_env("KUBERNETES_CLUSTER"),
  production_aliases: ["prod"],
  options: [env: %{"namespace" => System.get_env("KUBERNETES_NAMESPACE")}],
  session: :include_logger_metadata
```

* `:context_environment` - (binary or function returning binary) the deployment
  environment; used to set `notice.context.environment`.  See ["Setting the
  Environment in the Context"](context_environment.html) for more details.
  * This was formerly `:environment` which is now deprecated and will be removed
    in the next major release.
* `:production_aliases` - (list of strings) a list of `"production"` aliases for
  the environment.
* `:options` - (keyword list or function returning keyword list) values that are
  included in all notices posted to Airbrake.io.  See ["Shared
  Options"](shared_options.html) for more information.
* `:session` - can be set to `:include_logger_metadata` to include Logger
  metadata in the `session` field of the report; omit this option if you do not
  want Logger metadata.  See [The Session](session.html) for more details.

### Processing the payload when posting a notice

Use these options to change how the payload is processed when posting a notice
to Airbrake:

```elixir
config :airbrake_client,
  # ...
  filter_parameters: ["password"],
  filter_headers: ["authorization"],
  payload_processor: Airbrake.JasonPayloadProcessor
```

See `Airbrake.Utils.filter/2` for details about filtering.

* `:filter_parameters` - (list of strings) names of keys (strings or atoms) for
  sensitive data such as passwords and tokens.
* `:filter_headers` - (list of strings) names of HTTP headers (strings or atoms)
  to filter.
* `:payload_processor` - (module or tuple, defaults to
  `Airbrake.PoisonPayloadProcessor`)
  * See the [Payload Processor](payload_processor.html) guide for more
    details.
  * Replaces `:json_encoder` which is now **deprecated**,

`:json_encoder` is ignored if `:payload_processor` is set. If only
`:json_encoder` is set, the `:payload_processor` will be set to the appropriate
module. If neither `:json_encoder` nor `:payload_processor` is set, the library
will use `Airbrake.PoisonPayloadProcessor`.

### Ignoring exceptions

```elixir
config :airbrake_client,
  # ...
  ignore: :all
```

* `:ignore` has several possibilities:
    * `nil` (default) - skips nothing
    * `:all` to ignore all errors (useful in `test`)
    * MapSet of error modules to ignore
    * A function `(type, message -> boolean)`

See ["Ignoring Errors"](ignoring_errors.html).  Also see `Airbrake.Test` which
might affect your choice for `:ignore` in `test`.

## Usage

See the specific modules for more details.

* `Airbrake.report/1` to post a notice to Airbrake.
* `Airbrake.LoggerBackend` to post `Logger` error messages as notices to Airbrake.
* `Airbrake.Plug` to post a notice for an error in a `plug` pipeline.
* `Airbrake.Channel` to post a notice for an error on a web channel.
* `Airbrake.monitor/1` to post a notice for errors from a process.
* `Airbrake.GenServer` or `Airbrake.GenServer.handle_terminate/2` to post a
  notice when a `GenServer` terminates abnormally.
