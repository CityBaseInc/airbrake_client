# Airbrake Client

Capture exceptions and send them to [Airbrake](http://airbrake.io) or to
your [Errbit](http://errbit.com/) installation.

This library was originally forked from the
[`airbrake`](https://hex.pm/packages/airbrake) Hex package.  Development and
support for that library seems to have lapsed, but we (the devs at
[CityBase](https://thecitybase.com/)) had changes and updates we wanted to make.
So we decided to publish our own fork of the library.

## Installation

Add `airbrake_client` to your dependencies:

```elixir
defp deps do
  [
    {:airbrake_client, "~> 0.10"}
  ]
end
```

### Migrating from `airbrake`

If you are switching from the original `airbrake` library:

1. Replace the `:airbrake` dependency with the `:airbrake_client` dependency
   above.
    * You may want to start with version `~> 0.8.0` for maximum backwards
      compatibility.
1. Remove the `airbrake` dependency in your lockfile.
    * Command: `mix deps.unlock --unused`
    * If the dependency remains in the lockfile, check _all_ of your apps and
      _all_ of your dependencies.
1. Update your `config/*.exs` files to configure `:airbrake_client` instead of
   `:airbrake`.
    * A search-and-replace-in-project on `config :airbrake` can work really well.
    * When you run your project(even running the tests), you should get a
      complaint if you're still configuring `:airbrake`.

## Configuration

```elixir
config :airbrake_client,
  api_key: System.get_env("AIRBRAKE_API_KEY"),
  project_id: System.get_env("AIRBRAKE_PROJECT_ID"),
  environment: Mix.env(),
  filter_parameters: ["password"],
  filter_headers: ["authorization"],
  session: :include_logger_metadata,
  host: "https://api.airbrake.io" # or your Errbit host

config :logger,
  backends: [{Airbrake.LoggerBackend, :error}, :console]
```

Split this config across your `config/*.exs` files (especially the runtime
setting in `config/runtime.exs`).

Required configuration arguments:

  * `:api_key` - (binary) the token needed to access the [Airbrake
    API](https://airbrake.io/docs/api/). You can find it in [User
    Settings](https://airbrake.io/users/edit).
  * `:project_id` - (integer) the id of your project at Airbrake.

Optional configuration arguments:

  * `:environment` - (binary or function returning binary) the environment that
    will be attached to each reported exception.
  * `:filter_parameters` - (list of binaries) allows to filter out sensitive
    parameters such as passwords and tokens.
  * `:filter_headers` - (list of binaries) filters HTTP headers.
  * `:host` - (binary) the URL of the HTTP host; defaults to
    `https://api.airbrake.io`.
  * `:ignore` - (MapSet of binary or function returning boolean or :all) allows
    to ignore some or all exceptions.  See examples below.
  * `:options` - (keyword list or function returning keyword list) values that
    are included in all reports to Airbrake.io.  See examples below.
  * `:session` - can be set to `:include_logger_metadata` to include Logger
    metadata in the `session` field of the report; omit this option if you do
    not want Logger metadata.  See below for more information.

### Logger metadata in the `session`

If you set the `:session` config to `:include_logger_metadata`, the Logger
metadata from the process that invokes `Airbrake.report/2` will be the initial
session data for the `session` field.  The values passed as `:session` in the
`options` parameter of `Airbrake.report/2` are _added_ to the session value,
overwriting any Logger metadata values.

If you do not set the `:session` config, only the `:session` value passed as the
options to `Airbrake.report/2` will be used for the `session` field in the
report.

If the `session` turns out to be empty (for whatever reason), it is instead set
to `nil` (and should not show up in the report).

### Ignoring some exceptions

To ignore some exceptions use the `:ignore` config key.  The value can be a
`MapSet`:

```elixir
config :airbrake_client,
  ignore: MapSet.new(["Custom.Error"])
```

The value can also be a two-argument function:

```elixir
config :airbrake_client,
  ignore: fn type, message ->
    type == "Custom.Error" && String.contains?(message, "silent error")
  end
```

Or the value can be the atom `:all` to ignore all errors (and effectively
turning off all reporting):

```elixir
config :airbrake_client,
  ignore: :all
```

### Shared options for reporting data to Airbrake

If you have data that should _always_ be reported, they can be included in the
config with the `:options` key.  Its value should be a keyword list with any of
these keys: `:context`, `:params`, `:session`, and `:env`.

```elixir
config :airbrake_client,
  options: [env: %{"SOME_ENVIRONMENT_VARIABLE" => "environment variable"}]
```

Alternatively, you can specify a function (as a tuple) which returns a keyword
list (with the same keys):

```elixir
config :airbrake_client,
  options: {Web, :airbrake_options, 1}
```

The function takes a keyword list as its only parameter; the function arity is
always 1.

## Usage

### Phoenix app

```elixir
defmodule YourApp.Router do
  use Phoenix.Router
  use Airbrake.Plug # <- put this line to your router.ex

  # ...
end
```

```elixir
  def channel do
    quote do
      use Phoenix.Channel
      use Airbrake.Channel # <- put this line to your web.ex
      # ...
```

### Report an exception

```elixir
try do
  String.upcase(nil)
rescue
  exception -> Airbrake.report(exception)
end
```

### GenServer

Use `Airbrake.GenServer` instead of `GenServer`:

```elixir
defmodule MyServer do
  use Airbrake.GenServer
  # ...
end
```

### Any Elixir process

By pid:

```elixir
Airbrake.monitor(pid)
```

By name:

```elixir
Airbrake.monitor(Registered.Process.Name)
```

## Integration Apps

The Elixir apps defined in `integration_test_apps` are used for testing
different dependency scenarios.  If you make changes to the way `jason` or
`poison` is used this library, you should consider adding tests to those apps.
