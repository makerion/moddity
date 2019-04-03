defmodule Moddity.Driver do
  use GenServer

  @timeout 60_000
  @default_backend Moddity.PythonShellBackend

  defstruct []

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    backend = Keyword.get(opts, :backend, @default_backend)
    {:ok, %{backend: backend, last_status: nil}}
  end

  def get_status(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:get_status}, @timeout)
  end

  def load_filament(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:load_filament}, @timeout)
  end

  def send_gcode(file, opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:send_gcode, file}, @timeout)
  end

  def unload_filament(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:unload_filament}, @timeout)
  end

  def handle_call({:get_status}, _from, state) do
    case state.backend.get_status do
      {:ok, status} -> {:reply, {:ok, status}, %{state | last_status: status}}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:load_filament}, _from, state) do
    case state.backend.load_filament do
      :ok -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:send_gcode, file}, from, state) do
    Task.async(fn -> state.backend.send_gcode(file) end)
    {:noreply, Map.merge(state, %{from: from})}
  end

  def handle_call({:unload_filament}, _from, state) do
    case state.backend.unload_filament do
      :ok -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_info({sender, response}, state) do
    GenServer.reply(state.from, response)
    {:noreply, Map.delete(state, :from)}
  end
end
