defmodule Batcave do

  def sleep(ms), do: Process.sleep(ms)

  def progress_bar(current, target) do
    completed = Float.floor(30 * current / target) |> trunc

    ""
    |> String.pad_leading(completed, "\u2593")
    |> String.pad_trailing(30, "\u2591")

  end

  def progress(message, target, rate) do
    job = Pulsar.new_job()

    for i <- 0..target do
      Pulsar.message(job,
      "#{String.pad_trailing(message, 30)} #{progress_bar(i, target)} #{i}/#{target}")
      sleep(rate)
    end

    job
    |> Pulsar.status(:ok)
    |> Pulsar.complete()
  end

  def timed(message, ms) do
    job = Pulsar.new_job() |> Pulsar.message(message)

    sleep(ms)

    job
    |> Pulsar.message(message <> " \u2713")
    |> Pulsar.status(:ok)
    |> Pulsar.complete()

  end

  def run() do
    tasks = [
      Task.async(__MODULE__, :timed, ["Atomic turbines to speed", 3000]),
      Task.async(__MODULE__, :progress, ["Rotating Batmobile platform", 180, 35]),
      Task.async(__MODULE__, :timed, ["Initializing on-board Bat computer", 1800]),
      Task.async(__MODULE__, :progress, ["Loading Bat-fuel", 15, 250]),
    ]

    for task <- tasks, do: Task.await(task, 20000)

    Pulsar.new_job() |> Pulsar.message("Please fasten your Bat-seatbelts")

    # Give it a moment for final updates and all
    sleep(1500)
  end

end


Batcave.run()
