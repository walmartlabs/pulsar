defmodule Pulsar.Dashboard do
  @moduledoc """
  The logic for managing a set of jobs and updating them.
  """

  alias IO.ANSI
  alias __MODULE__.Terminal, as: T

  # jobs is a map from job id to job
  # new_jobs is a count of the number of jobs added since the most recent flush, e.g., number of new lines to print on next flush
  defstruct jobs: %{}, new_jobs: 0, active_highlight_duration: 0

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
  * `:prefix` - a string
  * `:status` - an atom, one of `:normal`, `:error`, or `:ok`

  Returns the updated dashboard.
  """
  def update_job(dashboard = %__MODULE__{}, jobid, job_data) do

    job = dashboard.jobs[jobid]

    if job && not(job.completed) do
      new_job = Enum.into(job_data, %{job | dirty: true,
      active: true,
      active_until: active_until(dashboard)})

      put_in(dashboard.jobs[jobid], new_job)
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
      job = %{
        status: :normal,
        prefix: nil,
        message: nil,
        dirty: true,
        line: 1,
        active: true,
        completed: false,
        active_until: active_until(dashboard),
      }

      updater = fn (jobs) ->
        jobs
        |> move_each_job_up()
        |> Map.put(jobid, job)
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
    job = jobs[jobid]
    unless job && not(job.completed) do
      dashboard # job gone or missing
    else
      new_job = %{job | dirty: true,
      completed: true,
      active: true,
      active_until: active_until(dashboard)}

      new_jobs = jobs
      |> Map.put(jobid, new_job)

      Map.put(dashboard, :jobs, new_jobs)
    end
  end

  @doc """
  Invoked periodically to clear the active flag of any job that has not been updated recently.
  Inactive jobs are marked dirty, to force a redisplay.
  """
  def update(dashboard = %__MODULE__{}) do
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

    # When there are new jobs, add blank lines to the output for those new jobs

    new_job_lines = if dashboard.new_jobs == 0 do
      []
    else
      for _ <- 1..dashboard.new_jobs, do: "\n"
    end

    dirty_job_groups = for {_, job} <- dashboard.jobs do
      if job.dirty do
        [
          T.cursor_invisible(),
          T.save_cursor_position(),
          T.cursor_up(job.line),
          T.leftmost_column(),
          (case {job.active, job.status} do
            {true, :error} -> ANSI.light_red()
            {_, :error} -> ANSI.red()
            {true, :ok} -> ANSI.light_green()
            {_, :ok} -> ANSI.green()
            {true, _} -> ANSI.light_white()
            _ -> nil
          end),
          job.prefix,
          job.message,
          T.clear_to_eol(),
          T.restore_cursor_position(),
          T.cursor_visible(),
          ANSI.reset()
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

      incomplete_line = dashboard.jobs
      |> Map.values()
      |> Enum.reject(fn m -> m.completed end)
      |> Enum.map(fn m -> m.line end)
      |> Enum.reduce(0, &max/2)

      # Everything has been flushed to screen and is no longer dirty.
      # Inactive, completed lines above incomplete_line are no longer
      # needed.
      new_jobs = Enum.reduce(dashboard.jobs,
       %{},
       fn {jobid, job}, m ->
          if job.completed && not(job.active) && job.line > incomplete_line do
            m
          else
            Map.put(m, jobid, %{job | dirty: false})
          end
        end)

      new_dashboard = %{dashboard | jobs: new_jobs, new_jobs: 0}

      {new_dashboard, all_chunks}
    end

    @doc """
    A variant of flush used to temporarily shut down the dashboard before
    some other output.

    Returns a tuple of the updated dashboard, and output.

    The output moves the cursor to the top line of the dashboard,
    then clears to the end of the screen. This temporarily removes
    the dashboard from visibility, so that other output can be produced.

    The returned dashboard is configured so that the next call to `flush/1`
    will add new lines for all jobs, and repaint all lines (e.g., as if
    every job was freshly added).
    """
    def pause(dashboard=%__MODULE__{}) do
      lines = Enum.count(dashboard.jobs) - dashboard.new_jobs
      output = if lines > 0 do
        [
          T.leftmost_column(),
          T.cursor_up(lines),
          T.clear_to_eos()
        ]
      end

      new_dashboard = dashboard
      |> update_each_job(fn job -> put_in(job.dirty, true) end)
      |> Map.put(:new_jobs, Enum.count(dashboard.jobs))

      {new_dashboard, output}
    end

    # -- PRIVATE --

    defp nil?(x), do: x == nil

    defp move_each_job_up(jobs) do
      # This shifts "up" all existing lines but *does not* mark them dirty
      # (because they are on the screen just like they should be).
      map_values(jobs, fn model -> update_in(model.line, &(&1 + 1)) end)
    end

    defp map_values(m = %{}, f) do
      m
      |> Enum.map(fn {k, v} -> {k, f.(v)} end)
      |> Enum.into(%{})
    end

    defp update_jobs(dashboard = %__MODULE__{}, f) do
      %{dashboard | jobs: f.(dashboard.jobs)}
    end

    defp update_each_job(dashboard , f) do
      update_jobs(dashboard, & map_values(&1, f))
    end

    defp active_until(dashboard) do
      System.system_time(:milliseconds) + dashboard.active_highlight_duration
    end
  end
