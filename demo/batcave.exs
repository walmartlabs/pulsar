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

    n = 2  # tuning factor

    tasks = [
      Task.async(__MODULE__, :timed, ["Atomic turbines to speed", n * 2000]),
      Task.async(__MODULE__, :progress, ["Rotating Batmobile platform", 180, n * 25]),
      Task.async(__MODULE__, :timed, ["Initializing on-board Bat-computer", n * 3000]),
      Task.async(__MODULE__, :progress, ["Loading Bat-fuel rods", 5, n * 750])
    ]

    sleep(n * 2500)
    Pulsar.pause()
    IO.write(
    """
           _,    _   _    ,_
      .o888P     Y8o8Y     Y888o.
     d88888      88888      88888b
    d888888b_  _d88888b_  _d888888b    Booting On-Board Bat-Computer ...
    8888888888888888888888888888888
    8888888888888888888888888888888
    YJGS8P"Y888P"Y888P"Y888P"Y8888P
     Y888   '8'   Y8P   '8'   888Y
      '8o          V          o8'
        `                     `
    """)
    Pulsar.resume()

    for task <- tasks, do: Task.await(task, 20000)

    Pulsar.new_job() |> Pulsar.message("Please fasten your Bat-seatbelts")

    # Give it a moment for final updates and all
    sleep(1500)
  end

end


Batcave.run()
