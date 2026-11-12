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

## Processing and filtering

The session is processed like the params, with
`c:Airbrake.PayloadProcessor.process_params/2` and the `:filter_parameters`
config option. The provided payload processors turn structs into maps and
tuples into lists, and they replace the values of the keys in
`:filter_parameters` with `"[FILTERED]"`. The session can have values that you
did not put there yourself, such as the `Logger` metadata or the assigns of a
socket from `Airbrake.Channel`, so add the keys of any sensitive data, such as
email addresses, to `:filter_parameters`.

The keys of maps in the session become strings, and a date or a time becomes a
map of its fields.
