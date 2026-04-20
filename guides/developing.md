# Developing the Library

## Integration Apps

The Elixir apps defined in `integration_test_apps` are used for testing
different dependency scenarios.  If you make changes to the way `jason` or
`poison` is used in this library, you should consider adding tests to those
apps.

To run all of these integration apps, run `./scripts/run_integration_tests`.
