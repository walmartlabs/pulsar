defmodule Pulsar.Dashboard do
  @moduledoc """
  The logic for managing a set of jobs and updating them.
  """

  defmodule Job do
    defstruct message: nil
  end

  # jobs is a map from job id to job model
  # new_jobs is a count of the number of jobs added since the most recent flush, e.g., number of new lines to print on next flush
  defstruct jobs: %{}, new_jobs: 0

  def new_dashboard() do
    %__MODULE__{}
  end

  @doc """
  Adds or updates a job to the dashboard, returning a modified dashboard.

  The jobid must be unique, and is typically the PID associated with the job.

  When a new job is added, it is added at line 1 (first line above the cursor), and any existing jobs are shifted up
  by a line.
  """
  def update_job(dashboard = %__MODULE__{}, jobid, job = %Job{} \\ %Job{}) do
    if Map.has_key?(dashboard.jobs, jobid) do
     model = %{dashboard.jobs[jobid] | job: job, dirty: true, last_update: System.os_time()}
     update_jobs(dashboard, &(Map.put &1, jobid, model))
   else
    model = %{dirty: true,
    line: 1,
    last_update: 0,
    job: job}

    # TODO: Sublime screws up the indentation starting here:

    dashboard
    |> update_jobs(fn jobs -> jobs |> move_each_job_up() |> Map.put(jobid, model) end)
    |> Map.update!(:new_jobs, &(&1 + 1))
  end
end

@doc """
  Flushes output of any dirty lines.
  """
  def flush(dashboard=%__MODULE__{}) do

    alias __MODULE__.Terminal, as: T

    # When there are new jobs, add blank lines to the output for those new jobs
    newlines(dashboard.new_jobs)

    for {_, model} <- dashboard.jobs do
      if model.dirty and model.job.message do
        IO.write  [
          T.cursor_invisible(),
          T.save_cursor_position(),
          T.cursor_up(model.line),
          T.leftmost_column(),
          model.job.message,
          T.clear_to_end(),
          T.restore_cursor_position(),
          T.cursor_visible()
        ]
      end
    end

    dashboard
    |> Map.put(:new_jobs, 0)
    |> update_each_job(&Map.put(&1, :dirty, false))

  end

  def demo() do

    d = new_dashboard() 
    |> update_job(:j1, %Job{message: "first job"}) 
    |> update_job(:j2, %Job{message: "second job"}) 
    |> flush()

    Process.sleep(1000)

    d = d
    |> update_job(:j2, %Job{message: "second job - updated"})
    |> update_job(:j1, %Job{message: "in place!"})
    |> flush()

    Process.sleep(1000)

    d |> update_job(:j1, %Job{message: "updated 2nd time"}) |> flush()

    Process.sleep(1000)

    d

  end



  # -- PRIVATE --

  def move_each_job_up(jobs) do
    # This shifts "up" all existing lines but *does not* mark them dirty
    # (because they are on the screen just like they should be).
    map_values(jobs, fn model -> update_in model.line, &(&1 + 1)  end)
  end

  def map_values(m = %{}, f) do
    m
    |> Enum.map(fn {k, v} -> {k, f.(v)} end)
    |> Enum.into(%{})
  end

  def update_jobs(dashboard = %__MODULE__{}, f) do
    %{dashboard | jobs: f.(dashboard.jobs) }
  end

  def update_each_job(dashboard , f) do
    update_jobs(dashboard, & map_values(&1, f))
  end

  def newlines(lines) do
    if lines > 0 do
      IO.puts ""
      newlines(lines - 1)
    end
  end

end



