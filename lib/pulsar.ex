defmodule Pulsar do
  @moduledoc """
  This is the client API for Pulsar.

  Pulsar manages a simple text-mode dashboard of jobs.

  Jobs can be updated at any time; updates appear *in place*.

  When a job is updated, it will briefly be repainted in bold and/or bright text,
  then be redrawn in standard text.
  This is to draw attention to changes.

  Completed jobs bubble up above any incomplete jobs.

  Jobs may have a status, which drives font color.  Normal jobs are in white.
  Jobs with status `:ok` are in green.
  Jobs with status `:error` are in red.

  Note that the actual colors are driven by the configuration of your terminal.

  Pulsar has no way to determine if other output is occuring.
  Care should be taken that logging is redirected to a file.
  Pulsar is appropriate to generally short-lived applications such as command line tools,
  who can ensure that output, including logging, is directed away from the console.

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

  Returns the job.
  """
  def message(job, message) do
    {process, jobid} = job
    GenServer.cast(process, {:update, jobid, message})
    job
  end

  @doc """
  Completes a previously created job. No further updates to the job
  should be sent.

  Returns the job.
  """
  def complete(job) do
    {process, jobid} = job
    GenServer.cast(process, {:complete, jobid})
  end

  @doc """
  Updates the status of the job.
  `status` should be `:normal`, `:ok`, or `:error`.

  Returns the job.
  """
  def status(job, status) do
    {process, jobid} = job
    GenServer.cast(process, {:status, jobid, status})
    job
  end

  @doc """
  Sets the prefix for the job; this immediately precedes the message.
  Generally, the prefix provides a job with a title.

  There is no seperator between the prefix and the message, a prefix
  typically ends with ": " or "- ".

  Returns the job.
  """
  def prefix(job, prefix) do
    {process, jobid} = job
    GenServer.cast(process, {:prefix, jobid, prefix})
    job
  end

  defp request_new_job(server) do
    process = GenServer.whereis(server)
    {process, GenServer.call(process, :job)}
  end

end
