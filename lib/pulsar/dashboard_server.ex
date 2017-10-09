defmodule Pulsar.DashboardServer do

  alias Pulsar.Dashboard, as: D

  @moduledoc """
  Responsible for managing a Dashboard, updating it based on received messages, and
  periodically flushing it to output.

  The `Pulsar` module is the client API for creating and updating jobs.

  The `:pulsar` application defines two configuration values:

  * `:flush_interval` - interval at which output is written to the console

  * `:active_highlight_duration` - how long an updated job is "bright"

  Both values are in milliseconds.

  Updates to jobs accumluate between flushes; this reduces the amount of output
  that must be written.
  """

  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(_) do
    enqueue_flush()
    {:ok, D.new_dashboard(Application.get_env(:pulsar, :active_highlight_duration))}
  end

  def terminate(_reason, state) do
    # TODO: Shutdown the dashboard properly, marking all jobs as complete
    {_, output} = D.flush(state)

    IO.write(output)
  end

  # -- requests sent from the client --

  def handle_call(:job, _from, state) do
    jobid = System.unique_integer()

    {:reply, jobid, D.add_job(state, jobid)}
  end

  def handle_cast({:update, jobid, message}, state) do
    {:noreply, D.update_job(state, jobid, message: message)}
  end

  def handle_cast({:complete, jobid}, state) do
    {:noreply, D.complete_job(state, jobid)}
  end

  def handle_cast({:status, jobid, status}, state) do
    {:noreply, D.update_job(state, jobid, status: status)}
  end

  def handle_info(:flush, state) do
    enqueue_flush()

    {dashboard, output} = state
    |> D.clear_inactive()
    |> D.flush()

    IO.write(output)

    {:noreply, dashboard}
  end

  defp enqueue_flush() do
    Process.send_after(self(), :flush, Application.get_env(:pulsar, :flush_interval))
  end

end
