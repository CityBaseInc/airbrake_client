# JsonOnlyApp

This app uses the `airbrake_client` app defined at the root of the git repository.

The app imports neither `jason` nor `poison`, relying on Erlang's built-in `:json`
module (OTP 27+) to ensure two things:
* Compiling the app without `jason` and `poison` is successful.
* Encoding with `:json` works just fine.
