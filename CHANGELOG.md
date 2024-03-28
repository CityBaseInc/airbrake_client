# Changelog for v0.x

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
