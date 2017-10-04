defmodule Pulsar.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {Pulsar.DashboardServer, name: Pulsar.DashboardServer}
    ]

    {:ok, _} = Supervisor.start_link(children, 
      strategy: :one_for_one, 
      name: Pulsar.Supervisor)
  end
end
