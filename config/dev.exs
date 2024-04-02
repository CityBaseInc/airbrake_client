import Config

# These settings can be used on the iex console.
# More are set in `config/runtime.exs`.
config :airbrake_client,
  session: :include_logger_metadata,
  private: [http_adapter: HTTPoison]
