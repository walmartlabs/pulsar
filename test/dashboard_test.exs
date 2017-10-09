defmodule DashboardTest do
  use ExUnit.Case
  doctest Pulsar.Dashboard

  alias Pulsar.Dashboard, as: D

  @root D.new_dashboard(1000)

  # Uses a bit of inside knowledge about the structure of the dashboard

  test "new dashboard is empty" do
    assert Enum.count(@root.jobs) == 0
  end

  test "jobs are added at bottom" do
    dashboard = @root
    |> add_job(1, "first")
    |> add_job(2, "second")
    |> flush()

    assert messages(dashboard) == ["first", "second"]
  end

  test "completed jobs bubble up" do
    dashboard = @root
    |> add_job(1, "first")
    |> add_job(2, "second")
    |> add_job(3, "third")
    |> D.complete_job(2)
    |> flush()

    # TODO: Eventually, flush() is going to remove completed jobs as well, once
    # they are no longer active.

    assert messages(dashboard) == ["second", "first", "third"]

    dashboard = dashboard
    |> D.complete_job(3)
    |> flush()

    assert messages(dashboard) == ["second", "third", "first"]

  end

  defp add_job(dashboard, id, message) do
    D.add_job(dashboard, id)
    |> D.update_job(id, job(message))
  end

  defp flush(dashboard) do
    {new_dashboard, _} = D.flush(dashboard)
    new_dashboard
  end

  defp job(message) do
    %D.Job{message: message}
  end

  defp messages(dashboard) do
    dashboard.jobs
    |> Map.values()
    |> Enum.sort_by(fn m -> m.line end, &>=/2)
    |> Enum.map(fn m -> m.job.message end)
  end

end
