import Config

case config_env() do
  :dev ->
    config :airbrake_client,
      api_key: System.get_env("AIRBRAKE_API_KEY", "fake-api-key"),
      project_id: System.get_env("AIRBRAKE_PROJECT_ID", "555"),
      host: System.get_env("AIRBRAKE_HOST", "https://api.airbrake.io")

  :test ->
    nil

  :prod ->
    nil
end
