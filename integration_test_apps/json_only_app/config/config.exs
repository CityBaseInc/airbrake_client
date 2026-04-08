import Config

config :airbrake_client,
  api_key: "TEST_KEY",
  project_id: 1,
  payload_processor: Airbrake.JsonPayloadProcessor
