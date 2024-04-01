import Config

case config_env() do
  :dev ->
    config :airbrake_client,
      api_key: System.get_env("AIRBRAKE_API_KEY"),
      project_id: System.get_env("AIRBRAKE_PROJECT_ID"),
      host: System.get_env("AIRBRAKE_HOST", "https://api.airbrake.io")

  :test ->
    nil

  :prod ->
    nil
end
