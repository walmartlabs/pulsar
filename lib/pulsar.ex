defmodule Pulsar do
  @moduledoc """
  This is the client API for Pulsar.
  """

  @app_name Pulsar.DashboardServer

  def new_job() do
   request_new_job(@app_name)
 end

 def new_job(node) do
  request_new_job({@app_name, node})
end 

def message({process, jobid}, message) do
  GenServer.cast(process, {:update, jobid, message})
end

defp request_new_job(server) do
  process = GenServer.whereis(server)
  {process, GenServer.call(process, :job)}
end

end
