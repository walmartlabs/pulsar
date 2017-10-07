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
    enqueue_flush()
    {:ok, D.new_dashboard(@active_highlight_interval)}
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
    # TODO: This is an ugly way to handle updates,  Maybe an API
    # like update_job(dashboard, jobid, key/values) ?
    # Also, updates to unknown jobs should go into the aether, not recreate them
    job = %D.Job{message: message}
    
    {:noreply,  D.update_job(state, jobid, job)}
  end

  def handle_cast({:complete, jobid}, state) do
    {:noreply, D.complete_job(state, jobid)}
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
    Process.send_after(self(), :flush, @flush_interval)
  end

end
