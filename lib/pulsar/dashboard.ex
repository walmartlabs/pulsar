defmodule Pulsar.Dashboard do
  @moduledoc """
  The logic for managing a set of jobs and updating them.
  """

  alias IO.ANSI

  # jobs is a map from job id to job model
  # new_jobs is a count of the number of jobs added since the most recent flush, e.g., number of new lines to print on next flush
  defstruct jobs: %{}, new_jobs: 0, active_highlight_duration: 0

  @empty_job %{message: nil, status: :normal}

  @doc """
  Creates a new, empty dashboard.

  `active_highlight_duration` is the number of milliseconds that a newly added or updated job
  should be rendered as active (bright).  `clear_inactive` is used periodically to identify
  jobs that should be downgraded to inactive and re-rendered.
  """
  def new_dashboard(active_highlight_duration) when active_highlight_duration > 0 do
    %__MODULE__{active_highlight_duration: active_highlight_duration}
  end


  @doc """
  Updates an existing job in the dashboard, returning a modified dashboard.

  If the job does not exist, or is marked completed, the dashboard is returned unchanged.

  `job_data` is a keyword list of changes to make to the job.  Supported keys are:

  * `:message` - a string
  * `:status` - an atom, one of `:normal`, `:error`, or `:ok`

  Returns the updated dashboard.
  """
  def update_job(dashboard = %__MODULE__{}, jobid, job_data) do

    model = dashboard.jobs[jobid]

    if model && not(model.completed) do
      new_job = Enum.into(job_data, model.job)
      new_model = %{model | dirty: true,
      active: true,
      active_until: active_until(dashboard),
      job: new_job}

      Map.update!(dashboard, :jobs, &(Map.put &1, jobid, new_model))
    else
      dashboard
    end
  end

  @doc """
  Add a new job to the dashboard.

  Returns the dashboard unchanged if the jobid already exists.
  """
  def add_job(dashboard = %__MODULE__{}, jobid) when jobid != nil do
    if Map.has_key?(dashboard.jobs, jobid) do
      dashboard
    else
      model = %{
        dirty: true,
        line: 1,
        active: true,
        completed: false,
        active_until: active_until(dashboard),
        job: @empty_job
      }

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

  @doc """
  Marks a job as completed.  Completed jobs float to the top of the list, above any
  non-completed jobs.  Once marked as complete, a job is removed from the dashboard at the next
  flush.

  Returns the updated dashboard, or the input dashboard if the job doesn't exist or is already completed.
  """
  def complete_job(dashboard = %__MODULE__{}, jobid) when jobid != nil do
    jobs = dashboard.jobs
    model = jobs[jobid]
    unless model && not(model.completed) do
      dashboard # job gone or missing
    else
      line = model.line
      active_line = jobs
      |> Map.values()
      |> Enum.reject(fn m -> m.completed end)
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
      completed: true,
      line: active_line,
      active: true,
      active_until: active_until(dashboard)}

      new_jobs = jobs
      |> map_values(fix_line_number)
      |> Map.put(jobid, new_model)

      Map.put(dashboard, :jobs, new_jobs)
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
          (case {model.active, model.job.status} do
            {true, :error} -> ANSI.light_red()
            {_, :error} -> ANSI.red()
            {true, :ok} -> ANSI.light_green()
            {_, :ok} -> ANSI.green()
            {true, _} -> ANSI.light_white()
            _ -> nil
          end),
          model.job.message,
          T.clear_to_end(),
          T.restore_cursor_position(),
          T.cursor_visible()
        ]
        end
      end

      # IO.write hates nils, so we have to filter out nil groups,
      # and nil chunks.
      all_chunks = dirty_job_groups
      |> Enum.reject(&nil?/1)
      |> Enum.reduce([], &Enum.into/2)
      |> Enum.reject(&nil?/1)
      |> Enum.into(new_job_lines)


      # Inactive completed jobs can go now, everything else
      # has been flushed to screen and is no longer dirty.
      new_jobs = dashboard.jobs
      |> reject_values(fn m -> m.completed && not(m.active) end)
      |> map_values(fn m -> %{m | dirty: false} end)

      new_dashboard = %{dashboard | jobs: new_jobs, new_jobs: 0}

      {new_dashboard, all_chunks}
    end

    # -- PRIVATE --

    defp nil?(x), do: x == nil

    defp move_each_job_up(jobs) do
      # This shifts "up" all existing lines but *does not* mark them dirty
      # (because they are on the screen just like they should be).
      map_values(jobs, fn model -> update_in model.line, &(&1 + 1) end)
    end

    defp map_values(m = %{}, f) do
      m
      |> Enum.map(fn {k, v} -> {k, f.(v)} end)
      |> Enum.into(%{})
    end

    defp reject_values(m = %{}, f) do
      m
      |> Enum.reject(fn {_, v} -> f.(v) end)
      |> Enum.into(%{})
    end

    defp update_jobs(dashboard = %__MODULE__{}, f) do
      %{dashboard | jobs: f.(dashboard.jobs)}
    end

    defp update_each_job(dashboard , f) do
      update_jobs(dashboard, & map_values(&1, f))
    end

    defp constantly(x) do
      fn -> x end
    end

    defp active_until(dashboard) do
      System.system_time(:milliseconds) + dashboard.active_highlight_duration
    end
  end
