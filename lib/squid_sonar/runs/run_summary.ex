defmodule SquidSonar.Runs.RunSummary do
  @moduledoc """
  Compact run projection for list and dashboard views.
  """

  alias SquidMesh.Run

  @type t :: %__MODULE__{
          id: term(),
          workflow: module() | String.t() | nil,
          trigger: atom() | String.t() | nil,
          status: atom() | nil,
          current_step: atom() | String.t() | nil,
          inserted_at: DateTime.t() | NaiveDateTime.t() | nil,
          updated_at: DateTime.t() | NaiveDateTime.t() | nil
        }

  defstruct [
    :id,
    :workflow,
    :trigger,
    :status,
    :current_step,
    :inserted_at,
    :updated_at
  ]

  @doc false
  @spec from_run(Run.t()) :: t()
  def from_run(%Run{} = run) do
    %__MODULE__{
      id: run.id,
      workflow: run.workflow,
      trigger: run.trigger,
      status: run.status,
      current_step: run.current_step,
      inserted_at: run.inserted_at,
      updated_at: run.updated_at
    }
  end
end
