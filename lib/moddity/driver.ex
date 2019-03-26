defmodule Moddity.Driver do
  use GenServer

  defstruct []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def get_status do
    GenServer.call(__MODULE__, {:get_status})
  end

  def send_gcode(file) do
    GenServer.call(__MODULE__, {:send_gcode, file}, 60_000)
  end

  def handle_call({:get_status}, _from, state) do
    priv_dir = :code.priv_dir(:moddity)
    modt_status = Path.join([priv_dir, "mod-t-scripts", "modt_status.py"])
    with {response, 0} <- System.cmd("python3", [modt_status]),
         {:ok, parsed_response} <- Jason.decode(response) do

      {:reply, {:ok, parsed_response}, parsed_response}
    else
      {error, 1} ->
        {:reply, {:error, error}, state}
      {:error, error} ->
        case Regex.match?(~r/Device not found/, error) do
          true -> {:reply, {:error, "Device not found"}, state}
          false -> {:reply, {:error, "Unknown Error"}, state}
        end
      error ->
        IO.inspect error
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:send_gcode, file}, _from, state) do
    priv_dir = :code.priv_dir(:moddity)
    send_gcode = Path.join([priv_dir, "mod-t-scripts", "send_gcode.py"])
    gcode_file = Path.join([priv_dir, "mod-t-scripts", "testPrint.gcode"])

    with {response, 0} <- System.cmd("python3", [send_gcode, gcode_file]),
         {:ok, parsed_response} <- Jason.decode(response) do
      {:reply, :ok, state}
    else
      error -> {:reply, {:error, error}, state}
    end
  end
end
