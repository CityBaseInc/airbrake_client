defmodule Airbrake.Test do
  @moduledoc """
  Test support for applications using `airbrake_client`.

  If you use this library, the notices that the library posts in `test` will be
  fully processed up to but not including the HTTP request. You can check the
  payload to make sure the right data is being sent to Airbrake, or just simply
  verify that the JSON encoding succeeds.

  If you're happy setting `ignore: :all` in the config in `test`, then you don't
  need to follow the instructions in this module.

  ## Setup

  To mock HTTP requests, first define a mock using Mox (or any mocking library)
  for `HTTPoison.Base`:

  ```elixir
  # test/support/mocks.ex
  Mox.defmock(MyApp.MockHTTPoison, for: HTTPoison.Base)
  ```

  Then make two changes to the `:airbrake_client` config:
  * Set `:http_adapter` in the `:private` config to a mock.
  * Set `:ignore` to `nil`.

  ```elixir
  # config/test.exs
  config :airbrake_client,
    # ...
    private: [http_adapter: MyApp.MockHTTPoison],
    ignore: nil
  ```

  Then in your tests, use `Airbrake.Test.airbrake_post_mock_fun/1` so that you
  can make assertions on the data posted to Airbrake.

  See the documentation for these functions for more explanation and details.

  ## Synchronous Tests

  Because `airbrake_client` runs just one process (named `Airbrake.Worker`), you
  most likely have to run tests involving `airbrake_client` _synchronously_
  (`async: false`) so that the expectations made in the test process can be used
  in the `Airbrake.Worker` process.

  In Mox, this means running in global mode. Be sure to use the
  `Mox.set_mox_from_context/1` setup function to turn on global mode for a test
  module. You cannot use `Mox.allow/3` to share the expectations with the
  `Airbrake.Worker` process unless you have just _one_ test process for all
  tests involving `airbrake_client`.

  ## Example

  ```elixir
  defmodule MyApp.NoticePostingTest do
    use ExUnit.Case, async: false

    import Airbrake.Test
    import Mox

    setup :set_mox_from_context
    setup :verify_on_exit!

    test "reports an error to Airbrake" do
      expect(MyApp.MockHTTPoison, :post, airbrake_post_mock_fun())

      # call code that should trigger posting an Airbrake notice

      assert_receive {:airbrake_report, %{payload: payload}}
      decoded_payload = Jason.decode!(payload)
      # assertions on `decoded_payload`.
    end
  end
  ```

  If you just want to make sure the payload was built without errors, you can
  assert just on the tuple:

  ```elixir
  assert_receive {:airbrake_report, _}
  ```

  You don't have to receive the message at all, but the test won't fail if
  something goes wrong when creating the payload.
  """

  @doc """
  Returns an anonymous function suitable for use as the function for mocking a
  `post/3` call on an `HTTPoison.Base` mock.

  The function does several helpful things:
  * It sends
    ```elixir
    {:airbrake_report, %{url: url, payload: payload, headers: headers}}
    ```
    to `caller` (which is `self()` by default). Use
    `ExUnit.Assertions.assert_receive/3` to receive this message and test
    further; for example:
    ```elixir
    assert_receive {:airbrake_report, %{payload: payload}}, 500
    ```
  * It returns
    ```elixir
    {:ok, %HTTPoison.Response{status_code: 201}}
    ```

  The returned function works with Mox and anything based off of Mox.  It may be
  useful for other mocking libraries, too.
  """
  @spec airbrake_post_mock_fun(pid()) :: (String.t(), String.t(), list() -> {:ok, map()})
  def airbrake_post_mock_fun(caller \\ self()) when is_pid(caller) do
    fn url, payload, headers ->
      send(caller, {:airbrake_report, %{url: url, payload: payload, headers: headers}})
      {:ok, %HTTPoison.Response{status_code: 201}}
    end
  end
end
