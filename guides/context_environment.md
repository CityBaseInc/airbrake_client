# Setting the Environment in the Context

The value for `notice.context.environment` when [creating a
notice](https://docs.airbrake.io/docs/devops-tools/api/#create-notice-v3) can be
set with the `:context_environment` config.

Often it is easiest to configure `:context_environment` with some environment
variable.  However, to get production notifications, the `environment` must be
set to `"production"` (case independent).  Maybe your environment variable
returns the value `"prod"`.  Set `:production_aliases` to a list of strings that
should be converted into `"production"`.  Consider this config:

```elixir
config :airbrake_client,
  context_environment: System.get_env("KUBERNETES_CLUSTER"),
  production_aliases: ["prod"],
```

If `KUBERNETES_CLUSTER` is `"prod"`, then `notice.context.environment` will be
set to `"production"`.

`:environment` is a deprecated attribute for `:context_environment`.  You will
get a warning when the app starts if you set it.  `:context_environment` has a
higher priority if you specify both.
