# Migrating from `airbrake`

If you are switching from [the original `airbrake`
library](https://hex.pm/packages/airbrake):

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
    * When you run your project (even running the tests), you should get a
      complaint if you're still configuring `:airbrake`.
