defmodule Pulsar.DashboardServer do

  alias Pulsar.Dashboard, as: D

  @moduledoc """
  Responsible for managing a Dashboard, updating it based on received messages, and
  periodically flushing it to output.
  """

  use GenServer

  @flush_interval 100  # milliseconds
  @active_highlight_interval 1000  # milliseconds

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(_) do
    ping()
    {:ok, D.new_dashboard(@active_highlight_interval)}
  end

  def terminate(_reason, state) do
    # TODO: Shutdown the dashboard properly, marking all jobs as complete
    D.flush(state)
  end

  # -- requests sent from the client --

  def handle_call(:job, _from, state) do
    jobid = System.unique_integer()

    enqueue_clear_inactive()

    {:reply, jobid, D.update_job(state, jobid)}
  end

  def handle_cast({:update, jobid, message}, state) do
    # TODO: This is an ugly way to handle updates,  Maybe an API
    # like update_job(dashboard, jobid, key/values) ?
    job = %D.Job{message: message}
    
    enqueue_clear_inactive()

    {:noreply,  D.update_job(state, jobid, job)}
  end

  def handle_info(:flush, state) do
    ping()
    {:noreply, D.flush(state)}
  end

  def handle_info(:clear_inactive, state) do
    {:noreply, D.clear_inactive(state)}
  end

  defp ping() do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp enqueue_clear_inactive() do
    Process.send_after(self(), :clear_inactive, @active_highlight_interval)
  end

end
