# Airbrake Client

Capture exceptions and post notices for them to [Airbrake](http://airbrake.io)
or to your [Errbit](http://errbit.com/) installation.

This library is a fork of the [`airbrake`](https://hex.pm/packages/airbrake)
Hex package, maintained by the devs at Euna Payments (formerly CityBase). See
[Migrating from `airbrake`](migrating.html) if you are switching.

[Documentation is available on
hexdocs.pm](https://hexdocs.pm/airbrake_client/readme.html).

## Installation

Add `airbrake_client` to your dependencies:

```elixir
defp deps do
  [
    {:airbrake_client, "~> 3.0.0-rc"}
  ]
end
```

A requirement has to name the pre-release to match a release candidate
(`"~> 3.0"` does not match `3.0.0-rc.0`). Use `"~> 3.0"` once 3.0.0 is
released.

## Configuration

Configure `:airbrake_client` in your `config/*.exs` files. Only the `:api_key`
and `:project_id` options are required.

`airbrake_client` checks its config when it starts, so `:api_key` and
`:project_id` need values in every environment, including `dev` and `test`.
`System.get_env/1` returns `nil` for an unset variable, and a `nil` value stops
your app. Use placeholders where you don't need the real values (and set
`ignore: :all` there; see `:ignore` below), and read the real values
in `config/runtime.exs`:

```elixir
# config/config.exs
config :airbrake_client,
  api_key: "placeholder",
  project_id: 0,
  host: "https://api.airbrake.io"

# config/runtime.exs
if config_env() == :prod do
  config :airbrake_client,
    api_key: System.fetch_env!("AIRBRAKE_API_KEY"),
    project_id: System.fetch_env!("AIRBRAKE_PROJECT_ID")
end
```

* `:api_key` - (**required**, binary) the token needed to access the [Airbrake
  API](https://airbrake.io/docs/api/). You can find it in [User
  Settings](https://airbrake.io/users/edit).
* `:project_id` - (**required**, integer or string) the id of your project at
  Airbrake.
* `:host` - (string) the URL of the HTTP host; defaults to
  `https://api.airbrake.io`.

### Optional settings

* `:context_environment` - (binary or function returning binary) the deployment
  environment for `notice.context.environment`. See ["Setting the Environment
  in the Context"](context_environment.html).
* `:production_aliases` - (list of strings) values of `:context_environment`
  that mean `"production"`. See ["Setting the Environment in the
  Context"](context_environment.html).
* `:options` - (keyword list or function) data included in every notice. See
  ["Shared Options"](shared_options.html).
* `:session` - set to `:include_logger_metadata` to put `Logger` metadata in
  `notice.session`. See ["The Session"](session.html).
* `:filter_parameters` - (list of strings) keys of sensitive params to filter.
  See `Airbrake.Utils.filter/2`.
* `:filter_headers` - (list of strings) HTTP headers to filter.
* `:payload_processor` - (module, defaults to `Airbrake.PoisonPayloadProcessor`)
  processes and encodes the payload. See ["Payload
  Processor"](payload_processor.html).
* `:ignore` - errors not to report, or `:all` to report none. See ["Ignoring
  Errors"](ignoring_errors.html), and `Airbrake.Test` for testing your app.

## Usage

See the specific modules for more details.

* `Airbrake.report/1` to post a notice to Airbrake.
* `Airbrake.LoggerBackend` to post `Logger` error messages as notices to Airbrake.
* `Airbrake.Plug` to add the details of the request to the notice for an error
  in a `plug` pipeline. It needs `Airbrake.LoggerBackend`.
* `Airbrake.Channel` to add the details of the channel to the notice for an
  error on a web channel. It needs `Airbrake.LoggerBackend`.
* `Airbrake.monitor/1` to post a notice for errors from a process.
* `Airbrake.GenServer.report_termination/2` to post a notice when a `GenServer`
  terminates abnormally.
