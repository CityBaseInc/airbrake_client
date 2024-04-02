import Config

# Do NOT set :host here so that default host in Airbrake.Worker can be tested.
config :airbrake_client,
  api_key: "TESTING_API_KEY",
  project_id: 8_675_309,
  private: [http_adapter: Airbrake.HTTPMock],
  filter_parameters: ["password"]
