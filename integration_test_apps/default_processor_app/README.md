# DefaultProcessorApp

This app uses the `airbrake_client` app defined at the root of the git repository.

The app does not configure a `payload_processor`, relying on the default
(`Airbrake.PoisonPayloadProcessor`). It includes `poison` as a dependency to
ensure the default processor works correctly when no explicit processor is set.
