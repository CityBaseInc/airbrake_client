# Testing an Integration

The examples in this guide post real notices so that you can check that your
app sends them to Airbrake. Run them in `iex -S mix` with your Airbrake
credentials, or in a remote console on a staging server. Then look for each
notice in Airbrake.

The examples use the type `"IntegrationTest"` so that you can find their
notices and resolve them when you are done.

## Before you start

Nothing tells you when a notice does not reach Airbrake. A wrong `:api_key`,
`:project_id`, or `:host` fails silently, and so does `ignore: :all`. Check
the config in the console:

```elixir
Application.get_all_env(:airbrake_client)
```

## A notice without options

```elixir
Airbrake.report(type: "IntegrationTest", message: "a notice without options")
```

The context has `environment` and `hostname`. The params and the environment
are `null`. The session is `null` too, unless it has `Logger` metadata (see
["The Session"](session.html)).

## A notice with every option

```elixir
Airbrake.report(
  [type: "IntegrationTest", message: "a notice with every option"],
  context: %{foo: 5},
  params: %{foo: {:a, "tuple"}},
  session: %{foo: 555},
  env: %{foo: 5555}
)
```

Each option has a different value so that you can see where it ends up. The
tuple in the params becomes a list.

If you set `:session` to `:include_logger_metadata`, set some metadata first:

```elixir
Logger.metadata(request_id: "abc123")
```

The session should then have `request_id` as well as `foo`.

## A rescued exception

```elixir
try do
  Map.fetch!(%{}, :missing)
rescue
  exception -> Airbrake.report(exception, stacktrace: __STACKTRACE__)
end
```

The type is `"KeyError"`, and the backtrace is the stacktrace of the
exception, not the stacktrace of the `Airbrake.report/2` call.

## Filtering

Use the keys from your own `:filter_parameters` and `:filter_headers` config:

```elixir
Airbrake.report(
  [type: "IntegrationTest", message: "filtering"],
  params: %{"password" => "not a real password", "user" => "alice"},
  env: %{headers: %{"authorization" => "Bearer not-a-real-token", "accept" => "text/html"}}
)
```

The values of the filtered keys are `"[FILTERED]"`. The other values are
unchanged.

## Monitored processes

`Airbrake.monitor/1` reports a process that exits abnormally. Start a process
and monitor it:

```elixir
pid = spawn(fn -> receive do: (:stop -> exit(:integration_test)) end)
Airbrake.monitor(pid)
```

Then stop it in a separate step:

```elixir
send(pid, :stop)
```

The notice has the type `"RuntimeError"` and the message `":integration_test"`.

Run the two steps separately. `Airbrake.monitor/1` returns before the worker
monitors the process, so if the process exits first, the notice has the
message `":noproc"` instead.

`Airbrake.monitor/1` does not report a normal exit. This should not post a
notice:

```elixir
pid = spawn(fn -> receive do: (:stop -> :ok) end)
Airbrake.monitor(pid)
```

```elixir
send(pid, :stop)
```

If you monitor a registered name instead of a pid, the name is the `component`
in the context.

## The logger backend

If you added `Airbrake.LoggerBackend`, a crash in a `Task` posts a notice from
the crash report in the log:

```elixir
Task.start(fn -> raise "integration test" end)
```

The type is `"RuntimeError"`, and the session has the `"function"` and
`"args"` of the task.

To test `Airbrake.Plug` or `Airbrake.Channel`, raise an exception in a
controller action or in a `handle_in/3` callback. The notice has the details of
the request or the channel.

## When a notice fails

A notice fails if its JSON encoding fails. Then `airbrake_client` posts a
fallback notice instead, with the type `"Airbrake.Notice.Error"`, and prints a
warning with the reason to stderr. This example fails because JSON cannot
encode a pid:

```elixir
Airbrake.report(
  [type: "IntegrationTest", message: "a pid in the params"],
  params: %{pid: self()}
)
```

Airbrake gets the fallback notice, not this one. The warning has only the type
of the original notice and the type of the error, not the message or the
params, because they might have sensitive data.
