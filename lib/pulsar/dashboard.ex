defmodule Pulsar.Dashboard do
  @moduledoc """
  The logic for managing a set of jobs and updating them.
  """

  alias IO.ANSI

  defmodule Job do
    defstruct message: nil
  end

  # jobs is a map from job id to job model
  # new_jobs is a count of the number of jobs added since the most recent flush, e.g., number of new lines to print on next flush
  defstruct jobs: %{}, new_jobs: 0, active_highlight_ms: 0

  @doc """
  Creates a new, empty dashboard.

  `active_highlight_ms` is the number of milliseconds that a newly added or updated job
  should be rendered as active (bright).  `clear_inactive` is used periodically to identify
  jobs that should be downgraded to inactive and re-rendered.
  """
  def new_dashboard(active_highlight_ms) do
    %__MODULE__{active_highlight_ms: active_highlight_ms}
  end


  @doc """
  Adds or updates a job to the dashboard, returning a modified dashboard.

  The jobid must be unique, and is typically the PID associated with the job.

  When a new job is added, it is added at line 1 (first line above the cursor), and any existing jobs are shifted up
  by a line.

  Returns the updated dashboard.
  """
  def update_job(dashboard = %__MODULE__{}, jobid, job = %Job{} \\ %Job{}) do
    active_until = System.system_time(:milliseconds) + dashboard.active_highlight_ms
    if Map.has_key?(dashboard.jobs, jobid) do
     model = %{
      dashboard.jobs[jobid] | job: job, 
      dirty: true, 
      active: true,
      active_until: active_until}
      update_jobs(dashboard, &(Map.put &1, jobid, model))
    else
      model = %{
        dirty: true,
        line: 1,
        active: true,
        active_until: active_until,
        job: job}

    # TODO: Sublime screws up the indentation starting here:

    dashboard
    |> update_jobs(fn jobs -> jobs |> move_each_job_up() |> Map.put(jobid, model) end)
    |> Map.update!(:new_jobs, &(&1 + 1))
  end
end

@doc """
Invoked periodically to clear the active flag of any job that has not been updated recently.
Inactive jobs are marked dirty, to force a redisplay.
"""
def clear_inactive(dashboard = %__MODULE__{}) do
  now = System.system_time(:milliseconds)

  updater = fn (job) ->
    if job.active and job.active_until <= now do
      %{job | active: false, dirty: true}
    else
      job
    end
  end

  update_each_job(dashboard, updater)
end

  @doc """
  Identify jobs that are 'dirty' (have pending updates) and redraws just those jobs
  in the dashboard.
  """
  def flush(dashboard=%__MODULE__{}) do

    alias __MODULE__.Terminal, as: T

    # When there are new jobs, add blank lines to the output for those new jobs
    newlines(dashboard.new_jobs)

    for {_, model} <- dashboard.jobs do
      if model.dirty and model.job.message do
        write [
          ANSI.reset(),
          T.cursor_invisible(),
          T.save_cursor_position(),
          T.cursor_up(model.line),
          T.leftmost_column(),
          (if model.active, do: ANSI.bright()),
          model.job.message,
          T.clear_to_end(),
          T.restore_cursor_position(),
          T.cursor_visible()]
        end
      end

      dashboard
      |> Map.put(:new_jobs, 0)
      |> update_each_job(&Map.put(&1, :dirty, false))

    end

  # -- PRIVATE --

  defp move_each_job_up(jobs) do
    # This shifts "up" all existing lines but *does not* mark them dirty
    # (because they are on the screen just like they should be).
    map_values(jobs, fn model -> update_in model.line, &(&1 + 1)  end)
  end

  defp map_values(m = %{}, f) do
    m
    |> Enum.map(fn {k, v} -> {k, f.(v)} end)
    |> Enum.into(%{})
  end

  defp update_jobs(dashboard = %__MODULE__{}, f) do
    %{dashboard | jobs: f.(dashboard.jobs)}
  end

  def update_each_job(dashboard , f) do
    update_jobs(dashboard, & map_values(&1, f))
  end

  defp newlines(lines) do
    if lines > 0 do
      IO.puts ""
      newlines(lines - 1)
    end
  end

  defp write(lines) do
    lines
    |> Enum.reject(&(&1 == nil))
    |> IO.write()
  end

end
