# Shared Options

If you have data that should _always_ be reported, they can be included in the
config with the `:options` option.  Its value should be a keyword list with any
of these keys: `:context`, `:params`, `:session`, and `:env`.

```elixir
config :airbrake_client,
  options: [env: %{"SOME_ENVIRONMENT_VARIABLE" => "environment variable"}]
```

Alternatively, you can specify a function (as a tuple) which returns a keyword
list (with the same keys):

```elixir
config :airbrake_client,
  options: {MyApp, :airbrake_options, 1}
```

The function takes a keyword list as its only parameter; the function arity is
always 1.
