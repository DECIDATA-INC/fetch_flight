defmodule FetchFlight.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = if Code.ensure_loaded?(FetchFlight.Browser), do: [FetchFlight.Browser], else: []

    Supervisor.start_link(children, strategy: :one_for_one, name: FetchFlight.Supervisor)
  end
end
