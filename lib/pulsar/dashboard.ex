defmodule Pulsar.Dashboard do
  @moduledoc """
  The logic for managing a set of jobs and updating them.
  """

  alias IO.ANSI
 
  defmodule Job do
    @moduledoc false

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
    active_until = active_until(dashboard)
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

    updater = fn (jobs) ->
      jobs
      |> move_each_job_up()
      |> Map.put(jobid, model)
    end

    dashboard
    |> update_jobs(updater)
    |> Map.update!(:new_jobs, &(&1 + 1))
  end
end

defp active_until(dashboard) do
  System.system_time(:milliseconds) + dashboard.active_highlight_ms
end

@doc """
Marks a job as completed.  Completed jobs float to the top of the list, above any
non-completed jobs.  Once marked as complete, a job is removed from the dashboard at the next
flush.
"""
def complete_job(dashboard = %__MODULE__{}, jobid) do
  jobs = dashboard.jobs
  model = jobs[jobid]
  unless model do
    dashboard # job gone or missing
  else
    line = model.line
    active_line = jobs
    |> Map.values()
    |> Enum.reject(fn m -> m[:completed] end)
    |> Enum.map(fn m -> m.line end)
    |> Enum.max(constantly(1))

    fix_line_number = fn m ->
      if m.line <= active_line and m.line > line do
        %{m | line: m.line - 1, dirty: true}
      else
        m
      end
    end

    new_model = %{model | dirty: true,
    line: active_line,
    active: true,
    active_until: active_until(dashboard)}
    |> Map.put(:completed, true)

    new_jobs = jobs
    |> map_values(fix_line_number)
    |> Map.put(jobid, new_model)
    %{dashboard | jobs: new_jobs}
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

  Returns a tuple of the updated dashboard and a enum of strings to send to `IO.write`.
  """
  def flush(dashboard=%__MODULE__{}) do

    alias __MODULE__.Terminal, as: T

    # When there are new jobs, add blank lines to the output for those new jobs
    
    new_job_lines = if dashboard.new_jobs == 0 do
      []
    else
      for _ <- 1..dashboard.new_jobs, do: "\n"
    end

    dirty_job_groups = for {_, model} <- dashboard.jobs do
      if model.dirty and model.job.message do
       [
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

    all_lines = dirty_job_groups
    |> Enum.reject(&nil?/1)
    |> Enum.reduce([], &Enum.into/2)
    |> Enum.reject(&nil?/1)
    |> Enum.into(new_job_lines)

    new_dashboard = dashboard
    |> Map.put(:new_jobs, 0)
    |> update_each_job(&Map.put(&1, :dirty, false))

    {new_dashboard, all_lines}
  end

  # -- PRIVATE --

  defp nil?(x), do: x == nil

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

  defp constantly(x) do
    fn -> x end
  end

end
