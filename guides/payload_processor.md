# Payload Processor

The `Airbrake.PayloadProcessor` behaviour specifies three callbacks that are
used when processing the payload sent to Airbrake.

* `c:Airbrake.PayloadProcessor.process_params/2` processes the `params`
  attribute in an Airbrake notice.  It should filter sensitive data and
  transform the data into a form that can be encoded with `encode!/1`.
* `c:Airbrake.PayloadProcessor.process_headers/2` filters sensitive data from
  the headers included in the `environment` of an Airbrake notice.
* `c:Airbrake.PayloadProcessor.encode!/1` encodes the entire payload into a
  JSON string.

`airbrake_client` comes with three implementations of
`Airbrake.PayloadProcessor`, and any of them can be used for the
`:payload_processor` config attribute.  Each one has a dependency on another
library which you have to explicitly specify.

* `Airbrake.PoisonPayloadProcessor` (default, depends on `poison`)
    * `process_params/2` calls `Airbrake.Utils.destruct/1`,
      `Airbrake.Utils.filter/2`, and `Airbrake.Utils.detuple/1`.
    * `process_headers/2` calls `Airbrake.Utils.filter/2`.
    * `encode!/1` calls `Poison.encode!/1`.
* `Airbrake.JasonPayloadProcessor` (depends on `jason`)
    * `process_params/2` calls `Airbrake.Utils.destruct/1`,
      `Airbrake.Utils.filter/2`, and `Airbrake.Utils.detuple/1`.
    * `process_headers/2` calls `Airbrake.Utils.filter/2`.
    * `encode!/1` calls `Jason.encode!/1`.
* `Airbrake.JsonPayloadProcessor` (available with OTP 27.0+)
    * `process_params/2` calls `Airbrake.Utils.destruct/1`,
      `Airbrake.Utils.filter/2`, and `Airbrake.Utils.detuple/1`.
    * `process_headers/2` calls `Airbrake.Utils.filter/2`.
    * `encode!/1` calls `:json.encode/1`.

You can write your own payload processor if you like.  See the
`Airbrake.PayloadProcessor` behaviour for more details.

If set, `:payload_processor` is used, and `:json_encoder` (if set) is ignored.
If you set `:json_encoder` instead of `:payload_processor`, the appropriate
payload processor is used.  Any use of `:json_encoder` results in a warning that
it is deprecated on start up.  It will be removed in the next major release.
