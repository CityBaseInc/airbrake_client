import Config

# These settings can be used on the iex console.
config :airbrake_client,
  api_key: {:system, "AIRBRAKE_API_KEY"},
  project_id: {:system, "AIRBRAKE_PROJECT_ID"},
  host: {:system, "AIRBRAKE_HOST", "https://api.airbrake.io"},
  private: [http_adapter: HTTPoison]
