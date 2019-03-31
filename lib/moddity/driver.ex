defmodule Moddity.Driver do
  use GenServer

  @timeout 60_000

  defstruct []

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def get_status do
    GenServer.call(__MODULE__, {:get_status}, @timeout)
  end

  def load_filament do
    GenServer.call(__MODULE__, {:load_filament}, @timeout)
  end

  def send_gcode(file) do
    GenServer.call(__MODULE__, {:send_gcode, file}, @timeout)
  end

  def unload_filament do
    GenServer.call(__MODULE__, {:unload_filament}, @timeout)
  end

  def handle_call({:get_status}, _from, state) do
    modt_status = Path.join([priv_dir(), "mod-t-scripts", "modt_status.py"])
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

  def handle_call({:load_filament}, _from, state) do
    load_filament_script = Path.join([priv_dir(), "mod-t-scripts", "load_filament.py"])

    with {response, 0} <- System.cmd("python3", [load_filament_script]) do
      IO.inspect response
      {:reply, :ok, state}
    else
      error -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:send_gcode, file}, _from, state) do
    send_gcode = Path.join([priv_dir(), "mod-t-scripts", "send_gcode.py"])

    with {response, 0} <- System.cmd("python3", [send_gcode, file]),
         {:ok, parsed_response} <- Jason.decode(response) do
      {:reply, :ok, state}
    else
      error -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:unload_filament}, _from, state) do
    unload_filament_script = Path.join([priv_dir(), "mod-t-scripts", "unload_filament.py"])

    with {response, 0} <- System.cmd("python3", [unload_filament_script]) do
      IO.inspect response
      {:reply, :ok, state}
    else
      error -> {:reply, {:error, error}, state}
    end
  end

  defp priv_dir do
    priv_dir = :code.priv_dir(:moddity)
  end
end
