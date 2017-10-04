defmodule Pulsar.DashboardServer do

  alias Pulsar.Dashboard, as: D

  @moduledoc """
  Responsible for managing a Dashboard, updating it based on received messages, and
  periodically flushing it to output.
  """

  use GenServer

  @flush_interval 100

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(_) do
    ping()
    {:ok, %{dashboard: D.new_dashboard(), jobid: 1}}
  end

  def terminate(_reason, state) do
    # TODO: Shutdown the dashboard properly, marking all jobs as complete
    D.flush(state.dashboard)
  end

  # -- requests sent from the client --

  def handle_call(:job, _from, state) do
    %{jobid: jobid} = state
    {:reply, jobid, 
    state
    |> Map.put(:jobid, jobid + 1)
    |> Map.update!(:dashboard, &(D.update_job &1, jobid))}
  end

  def handle_cast({:update, jobid, message}, state) do
    # TODO: This is an ugly way to handle updates,  Maybe an API
    # like update_job(dashboard, jobid, key/values) ?
    job = %D.Job{message: message}
    {:noreply, 
    Map.update!(state, :dashboard, &(D.update_job &1, jobid, job))}
  end

  def handle_info(:flush, state) do
    ping()
    {:noreply, Map.update!(state, :dashboard, &D.flush/1)}
  end

  defp ping() do
    Process.send_after(self(), :flush, @flush_interval)
  end

end
