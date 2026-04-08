# The Session

If `notice.session` turns out to be empty (for whatever reason), it is instead
set to `nil` (and should not show up in the report).

## Logger metadata in the `session`

If you set the `:session` config option to `:include_logger_metadata`, the
`Logger` metadata from the process that invokes `Airbrake.report/2` will be the
initial session data for the `session` field.

If you set `:session` in `:options` config option, this value will be merged
into the `Logger` metadata if you use `:include_logger_metadata`. For any
duplicate keys, the `:options` setting has priority.
