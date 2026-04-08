# Changelog

## v2.3.0-rc.0 (2026-03)

The v2.3.0 release makes configuration and JSON encoding much better and less
risky.

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
