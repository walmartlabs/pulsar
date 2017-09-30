defmodule Walmart.Pulsar do
  @moduledoc """
  This is the client API for Pulsar.
  """

  @app_name Walmart.Pulsar.DashboardServer

  def job(node) do
    
    GenServer.call({@app_name, node}, :job)
  end 


end
