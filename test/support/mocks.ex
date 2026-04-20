Mox.defmock(Airbrake.MockHTTPoison, for: HTTPoison.Base)
Mox.defmock(MockConfig, for: Airbrake.Config.Behaviour)
Mox.defmock(Airbrake.MockPayloadProcessor, for: Airbrake.PayloadProcessor)
