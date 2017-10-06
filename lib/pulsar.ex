defmodule Pulsar do
  @moduledoc """
  This is the client API for Pulsar.
  """

  @app_name Pulsar.DashboardServer

  @doc  """
  Creates a new job using the local server.

  Returns a job tuple that may be passed to the other functions.
  """
  def new_job() do
   request_new_job(@app_name)
 end

@doc """
Creates a new job using a remote server, from the `node` parameter.
"""
def new_job(node) do
  request_new_job({@app_name, node})
end 

@doc """
Given a previously created job, updates the message for the job.

This will cause the job's line in the dashboard to update, and will briefly be
highlighted.

Returns :ok
"""
def message(job, message) do
  {process, jobid} = job
  GenServer.cast(process, {:update, jobid, message})
end

@doc """
Completes a previously created job. No further updates to the job
should be sent.be

Returns :ok.
"""
def complete(job) do
  {process, jobid} = job
  GenServer.cast(process, {:complete, jobid})
end

defp request_new_job(server) do
  process = GenServer.whereis(server)
  {process, GenServer.call(process, :job)}
end

end
