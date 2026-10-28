# Changelog

## Unreleased

Breaking changes:
* The minimum Elixir version is now 1.17. Elixir 1.16 only runs on Erlang/OTP
  versions that have reached end of life.
* `httpoison` 1.x is no longer supported. `httpoison` 2.x and 3.x are supported.
  `httpoison` 3.x uses `hackney` 4.x, which requires Erlang/OTP 26 or later.
* `use Airbrake.GenServer` is no longer supported, and it raises an error at
  compile time. Call `Airbrake.GenServer.report_termination/2` from the
  `terminate/2` callback of your `GenServer` instead. The notice no longer has
  the inspected state of the `GenServer` in its context, which could include
  secrets or personal data. Add only what you need to the options you pass to
  `report_termination/2`.
* `Airbrake.LoggerBackend` puts the `Key: value` lines and the title of a log
  message in the session instead of the context. Before, a line such as
  `Environment: staging` could replace a context field that Airbrake
  recognizes.
* `Airbrake.Channel` puts the channel module, the event, and the topic in the
  `component`, `action`, and `route` fields of the context instead of
  `channel` and `msg_type`.
* `Airbrake.Plug` sends the client address as `userAddr` instead of `userIP`,
  which Airbrake did not recognize. It no longer sends `cookies` in the
  context. The cookies are still in the `"cookie"` request header, where
  `:filter_headers` can filter them.

**Channel errors:** An error in the `handle_info/2` callback of a channel no
longer crashes the worker. The message is in the params as `message`.

**Anonymous function frames:** A stacktrace with an anonymous function frame
(`{fun, arity, location}`) is now reported. Before, the notice failed, and
the worker crashed.

**Plug and Channel details:** `Airbrake.Plug` and `Airbrake.Channel` add their
details to the notice from `Airbrake.LoggerBackend` for an exception with a
message of more than one line, such as a `KeyError`. Before, the backend
reported only the first line of the message, which did not match the
remembered exception, and the details were lost. The docs now say that both
modules need `Airbrake.LoggerBackend`.

**GenServer termination:** `Airbrake.GenServer.report_termination/2` replaces
`Airbrake.GenServer.handle_terminate/2`, which is deprecated.
* `report_termination/2` takes the options of `Airbrake.report/2`, so you can
  set the context and the session. `handle_terminate/2` still takes a context
  map.
* A raised exception is now reported with its own type, message, and
  stacktrace. Before, it was reported as a `RuntimeError` with the inspected
  `{exception, stacktrace}` tuple as its message.
* An Erlang error is now reported as the matching Elixir exception with its
  stacktrace. For example, `{:badmatch, 1}` is reported as a `MatchError`
  instead of a `RuntimeError`.
* `Airbrake.monitor/1` also gets these fixes.
* `Airbrake.monitor/1` no longer puts `process_name` in the context. If you
  monitor a registered name, the name is the `component` of the context, which
  Airbrake recognizes. The session has the inspected process as `process`.

**Logger backend:** `Airbrake.LoggerBackend` builds better notices from log
messages.
* The backtrace is the stacktrace lines after the exception message, even if
  the message has more than one line. Lines without an `(app vsn)` prefix, such as
  `lib/my_app/worker.ex:12: MyApp.Worker.run/1`, are now in the backtrace
  instead of the context. Other stacktrace lines, such as the client's
  stacktrace in a GenServer crash report, are no longer in the backtrace or the
  context.
* For a nested exception, such as an exception raised in a `GenServer` during
  a `GenServer.call/3`, the backtrace is the stacktrace of the nested
  exception instead of the stacktrace of the caller. The `** ` lines around
  it, such as `** (stop) exited in: GenServer.call(...)`, are in the session
  as `reason`.
* The backend is no longer removed from `Logger` when it fails to handle a
  log message. It prints a warning with the type of the error to stderr.
* The backend no longer creates atoms from the text of log messages.
* The backend no longer prints exceptions with `IO.inspect/1`.
* The docs explain how to set up the backend with `logger_backends` and describe
  what the backend reports, with a warning about sensitive data.

## v3.0.0-rc.0 (2026-04-17)

The v3.0.0 release makes configuration and JSON encoding much better and less
risky.

This is a major version because the new config validator can stop an app from
starting: unknown keys, a missing `api_key` or `project_id`, or a value of the
wrong type now fail validation (see "Breaking changes" below). 3.0.0-rc.0 is
meant to be an easy update: deprecated functions and config options still work
and print warnings. A later release candidate, planned as 3.0.0-rc.1, will
remove the deprecated functions and config options and raise the minimum Elixir
version.

**Config validator:**  We now have a validator which checks the application
config to make sure that it has everything it needs, doesn't have things it
doesn't need, and that the config values are acceptable. If something is broken,
_the worker will fail to start_, and your app will crash.

Breaking changes:
* Unknown config keys cause validation to fail; previously they were silently
  ignored.
* `api_key` and `project_id` are required. You might need to set them in `dev`
  and `test` environments.
* Config values are type-checked. Validation fails if a value has the wrong
  shape:
    * `:api_key` — string, `{:system, var}`, or `{:system, var, default}`
    * `:project_id` — integer, integer-parseable string, `{:system, var}`, or
      `{:system, var, default}`
    * `:host` — string, `{:system, var}`, or `{:system, var, default}`
    * `:context_environment` (and `:environment`) — string, atom, `{:system,
      var}`, or 0-arity function
    * `:ignore` — `nil`, `:all`, a `MapSet`, or a 2-arity function
    * `:options` — keyword list or `{mod, fun, 1}` tuple
    * `:session` — `:include_logger_metadata` or `nil`
    * `:filter_parameters` — list of strings
    * `:filter_headers` — list of strings
    * `:production_aliases` — list of strings
    * `:json_encoder` — module
    * `:payload_processor` — module that is loaded and implements
      `process_params/2`, `process_headers/2`, and `encode!/1`
    * `:private` — keyword list
* If no `:payload_processor` is configured, the `:json_encoder` module
  (defaulting to `Poison`) must be loadable.

The validator will also output warnings to stderr. It is recommended that you
watch your app's output careful the first time you deploy an app after updating
`airbrake_client`.

**Payload processor:** significant improvements have been made to filtering
params and headers and to JSON encoding the whole payload.

`Airbrake.PayloadProcessor` is a behaviour with three functions:

* `c:Airbrake.PayloadProcessor.process_params/2` turns the value for
  `notice.params` into something that should be encodable as a JSON string. It
  also filters out sensitive data.
* `c:Airbrake.PayloadProcessor.process_headers/2` filters sensitive data from
  HTTP headers found at `notice.environment.headers`.
* `c:Airbrake.PayloadProcessor.encode!/1` calls a JSON encoder.

You specify a _payload processor_ with the `:payload_processor` option in the
config, replacing the `:json_encoder` option. `airbrake_client` comes with
payload processors that you can use immediately:
`Airbrake.PoisonPayloadProcessor`, `Airbrake.JasonPayloadProcessor`,
`Airbrake.JsonPayloadProcessor`.

See ["Payload Processor"](payload_processor.html) and the modules for more
details.

**Internal errors and exceptions:** internal errors that are raised (or thrown)
are now processed internally so that the worker process doesn't crash. There are
two levels:
* If the worker process raises an error, the error is caught, and a very generic
  notice is posted to Airbrake.
    * The notice is generic so that posting the second notice is very likely to
      succeed.
* If posting the generic notice to Airbrake raises an error, the error is caught
  and a simple warning is output to stderr.

We cannot use `Logger` because the logger backend might trigger posting another
notice to Airbrake and we'd end up in an infinite loop of errors.

### Enhancements

  * [Airbrake.Test] Add `airbrake_post_mock_fun/1` to return a function that
    implements an expectation for the `HTTPoison.Base.post/3` call to post a
    notice. See `Airbrake.Test` for more information and an example.
  * [Airbrake.Utils] Associative lists (including keyword lists) are now
    filtered by key in `Airbrake.Utils.filter/2`, matching atom keys as strings
    against the filtered attributes list.
  * [Airbrake.PayloadProcessor] Add `Airbrake.PayloadProcessor` behaviour with
    callbacks to process a notice payload posted to Airbrake.
  * [Airbrake.PoisonPayloadProcessor] Add `Airbrake.PayloadProcessor`
    implementation for Poison. Conditionally compiled when Poison is available.
  * [Airbrake.JasonPayloadProcessor] Add `Airbrake.PayloadProcessor`
    implementation for Jason. Conditionally compiled when Jason is available.
  * [Airbrake.JsonPayloadProcessor] Add `Airbrake.PayloadProcessor`
    implementation for Erlang's `:json`. Conditionally compiled when `:json` is
    available (OTP 27+).
  * [Airbrake.Config] Add `payload_processor/1` to resolve the configured
    `Airbrake.PayloadProcessor` module, with fallback from `:json_encoder`.
  * [Airbrake.Config] Allow the `:project_id` option to be an integer or a
    string containing an integer.
  * [Airbrake.Config.Validator] Add validation before the `airbrake_client`
    process is started. Shows warnings for deprecated options.
  * [Airbrake.Utils] Make the module public with documentation; use to write
    your own payload processors.

### Deprecations

  * [Airbrake] `Airbrake.destruct/1` and `Airbrake.detuple/1` are deprecated;
    use same functions in `Airbrake.Utils`.
  * [Airbrake.Config.Validator] `:json_encoder` config key is deprecated; use
    `:payload_processor` instead.
  * [Airbrake.Config.Validator] `:environment` config key is deprecated; use
    `:context_environment` instead.

### Bug fixes

  * [Airbrake.PayloadTest] Fix fragile assertion on `UndefinedFunctionError`
    message that varied across Elixir/OTP versions.
  * [Airbrake.Plug] Handle IPv4 _and_ IPv6 addresses for the `userIP` in the
    context of a notice.
  * [Airbrake] Fix return type of `report/2` and `remember/2`.
  * [Airbrake.Utils] Update `Airbrake.Utils.filter/2` to recurse on tuples.
  * [Airbrake.Payload] Removed derived implementation of `Jason.Encoder` because
    the derived encoder did not work.


## v2.2.1 (2025-01-04)

### Bug fixes

* Handles a stacktrace entry that includes unexpected values.

## v2.2.0 (2024-05-10)

### Enhancements

* Better config name: `:context_environment` replaces `:environment` in the
  configuration.  `:environment` will continue to work for backwards compatibility.
* New config option: `:production_aliases` can be set to a list of names that
  should be translated to `"production"` for `notice.context.environment`.  See
  README for more details.
* New documentation for config option: `:json_encoder` is documented in the
  README.
* New JSON encoder protections:
    * If the JSON encoder module does not exist at compile time, the library
      will compile with an error.
    * If the JSON encoder module does not exist when
      `Airbrake.Worker` is started, the process will not start.
    * If the JSON encoder module _does_ exist but does not define `encode!/1`
      when a report is made, a warning will be output to stderr and a _very_
      simple Airbrake notice about the missing `encode!/1` function _will_ be
      sent.  Previously, the `Airbrake.Worker` would crash and take
      the app down with it without sending any Airbrake notices.

## v2.1.0 (??????????)

### Enhancements

  * New config option: if `:session` is set to `:include_logger_metadata`, the
    Logger metadata from `Logger.metadata/0` is added to the `session` field of
    the report.  (If the option is not set, the metadata is not included.)

## v2.0.0 (2024-03-11)

### Enhancements

  * [Airbrake.Utils] Add `detuple/1` to support CBRelay in parsing Airbrake params before transmitting
  * [Airbrake.Utils] Add `destruct/1` to support CBRelay in parsing Airbrake params before transmitting

### Breaking Change

  * Drop support for Elixir <1.12

## v1.0.0 (2023-10-12)

### Enhancements

  * [Airbrake.Worker] use only `Application.compile_env/3`, drop use of `Application.get_env/3`.
  * Formatting changes.
  * Allow version 1.X or 2.X for `httpoison`; drop support for 0.9.

### Breaking Change

  * Drop support for Elixir <1.10.  Use must use earlier version to compile with earlier versions of Elixir.

## v0.11.0 (2022-12-05)

  * [Airbrake.Plug] Exposes `handle_errors/2` as private
  * Fixes credo warnings

## v0.10.0 (2021-07-14)

  * [Airbrake.Payload] Support logging structs in payload.
  * [Airbrake.Payload] Filter atom keys from maps in payload.

## v0.9.1 (2021-06-08)

### Enhancements

  * [Airbrake] Updates default URL to `https://api.airbrake.io`.

### Bug fixes

  * [Airbrake] Add `:filter_headers` option to filter HTTP headers included in `:environment`.
  * [Airbrake.Payload] Conditionally derive `Jason.Encoder` if `Jason.Encoder` is defined (i.e., `jason` is a dependency).
  * [Airbrake.Payload] Add fields `context`, `environment`, `params`, and `session` to `Airbrake.Payload`.
  * [Airbrake.Worker] Generate a useable stacktrace when one isn't provided in the options.

## v0.9.0 (2021-06-04)

Fixes deprecations and improves testing.

### Enhancements

  * [Airbrake.Worker] Abstract HTTP client for better testing using `mox`.
  * [Airbrake.Worker] Add tests.
  * [Airbrake.LoggerBackend] Add tests.
  * [Airbrake.LoggerBackend] Use `@behaviour :gen_event` instead of `use GenEvent`.
  * [mix.exs] Start dependency applications automatically.

### Bug fixes

  * [Airbrake.Channel] Use `__STACKTRACE__` instead of deprecated `System.stacktrace()`.
  * [Airbrake.Worker] Use `Process.info(self(), :current_stacktrace)` instead of deprecated `System.stacktrace()`.
  * [Airbrake] Use child spec instead of deprecated Supervisor.Spec.worker/1.

## v0.8.2 (2021-06-03)

Renames the app to `:airbrake_client`.

### Bug fixes

  * [mix.exs] Renames the app to `:airbrake_client` so that starting the app for this library is more natural.

## v0.8.1 (2021-06-02)

Quick documentation fix.

### Bug fixes

  * [README.md] Use correct case when linking to `readme.html`.

## v0.8.0 (2021-06-02)

The first official release of `airbrake_client` (forked and disconnected from [`airbrake`](https://hex.pm/packages/airbrake)).

### Enhancements

  * [README.md] Update for new maintainers and better instructions.

## Previous versions

The CityBase fork of `airbrake` had a [v0.7.0 release](https://github.com/CityBaseInc/airbrake-elixir/releases/tag/0.7.0), available only through GitHub.

Versions 0.6.x are available as the original [`airbrake`](https://hex.pm/packages/airbrake) library.
