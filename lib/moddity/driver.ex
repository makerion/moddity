defmodule Moddity.Driver do
  @moduledoc """
  This module is the entrypoint for communication with a MOD-t printer.

  It maintains communication state and manages some primitive caching and
  handles returning last known state when another process is sending a command
  to the printer.
  """

  use GenServer

  @timeout 60_000
  @default_backend Moddity.Backend.PythonShell

  defstruct []

  alias Moddity.PrinterStatus

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    backend = Keyword.get(opts, :backend, @default_backend)

    {:ok,
     %{
       backend: backend,
       caller: nil,
       command_in_progress: false,
       last_status_fetch: 0,
       status: nil
     }}
  end

  def get_status(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:get_status, System.monotonic_time(:millisecond)}, @timeout)
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

  def handle_call({:get_status, _}, _from, state = %{command_in_progress: true}) do
    {:reply, {:ok, state.status}, state}
  end

  def handle_call({:get_status, now}, _from, state = %{last_status_fetch: fetched}) when now > fetched + 1000 do
    {:reply, {:ok, state.status}, state}
  end

  def handle_call({:get_status, _}, _from, state) do
    case state.backend.get_status() do
      {:ok, status} ->
        timestamp = System.monotonic_time()
        {:reply, {:ok, status}, %{state | status: status, last_status_fetch: timestamp}}

      {:error, error} ->
        {:reply, {:error, error}, state}
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
    status = %PrinterStatus{idle?: false, state: :sending_gcode}
    new_state = %{state | caller: from, command_in_progress: true, status: status}
    {:noreply, new_state}
  end

  def handle_call({:unload_filament}, _from, state) do
    case state.backend.unload_filament do
      :ok -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_info({_sender, response}, state) do
    GenServer.reply(state.caller, response)
    {:noreply, %{state | caller: nil}}
  end
end
