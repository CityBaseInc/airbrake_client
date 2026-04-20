defmodule Airbrake.TestSupport.Employee do
  @moduledoc """
  A simple struct with no JSON encoder implementation.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          age: non_neg_integer()
        }

  defstruct [:name, :age]
end

defmodule Airbrake.TestSupport.Boss do
  @moduledoc """
  A struct whose `hired_on` field may hold a `Date` or an Erlang-style date tuple.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hired_on: Date.t() | {non_neg_integer(), 1..12, 1..31}
        }

  defstruct [:name, :hired_on]
end

defmodule Airbrake.TestSupport.Team do
  @moduledoc """
  A struct containing a list of `Employee` and `Boss` members.
  """

  @type t :: %__MODULE__{
          members: [Airbrake.TestSupport.Employee.t() | Airbrake.TestSupport.Boss.t()]
        }

  defstruct [:members]
end
