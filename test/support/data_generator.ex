defmodule Airbrake.Test.DataGenerator do
  @moduledoc """
  Functions to generate data for property tests.
  """

  import StreamData

  def string_key do
    string(:alphanumeric, min_length: 3)
  end

  def context_environment do
    member_of(["dev", "development", "uat", "staging", "prod", "production"])
  end

  def hostname do
    string(:alphanumeric, min_length: 3)
  end
end
