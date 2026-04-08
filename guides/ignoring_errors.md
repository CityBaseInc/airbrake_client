# Ignoring Errors

You can ignore some exceptions with the `:ignore` config key.

The value can be a `MapSet`:

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

Set to `nil` (or don't configure the option) to process all errors.

Set to `:all` to ignore all errors (and effectively turning off all reporting):

```elixir
config :airbrake_client,
  ignore: :all
```

This can be useful in `test`, but consider using `Airbrake.Test` instead.
