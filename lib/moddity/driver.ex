defmodule Moddity.Driver do
  @moduledoc """
  This module is the entrypoint for communication with a MOD-t printer.

  It maintains communication state and manages some primitive caching and
  handles returning last known state when another process is sending a command
  to the printer.
  """

  use GenServer

  require Logger

  @timeout 60_000
  @default_backend Moddity.Backend.Libusb

  defstruct []

  alias Moddity.Firmware.Downloader
  alias Moddity.PrinterStatus

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    backend = Keyword.get(opts, :backend, @default_backend)
    if Keyword.get(opts, :poll, true) do
      Process.send_after(self(), :get_status, 100)
    end

    {:ok,
     %{
       backend: backend,
       caller: nil,
       command_in_progress: false,
       last_status_fetch: nil,
       status: nil,
       task: nil
     }}
  end

  def subscribe do
    Registry.register(Registry.PrinterStatusEvents, :printer_status_event, [])
  end

  def abort_print(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:abort_print}, @timeout)
  end

  def get_status(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:get_status, System.monotonic_time(:millisecond)}, @timeout)
  end

  def load_filament(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:load_filament}, @timeout)
  end

  def pause_printer(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:pause_printer}, @timeout)
  end

  def reset_printer(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:reset_printer}, @timeout)
  end

  def resume_printer(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:resume_printer}, @timeout)
  end

  def send_gcode(file, opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:send_gcode, file}, @timeout)
  end

  def send_gcode_command(line, opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:send_gcode_command, line}, @timeout)
  end

  def unload_filament(opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:unload_filament}, @timeout)
  end

  def update_firmware(url, expected_sha256, opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:update_firmware, url, expected_sha256}, @timeout)
  end

  def handle_call({:get_status, now}, _from, state = %{last_status_fetch: fetched})
  when ((not is_nil(fetched)) and now < fetched + 1000) do
    {:reply, {:ok, state.status}, state}
  end

  def handle_call({:get_status, _}, _from, state) do
    Tuple.insert_at(_get_status(state), 0, :reply)
  end

  def handle_call(_, _from, state = %{command_in_progress: true}) do
    {:reply, {:error, state.status}, state}
  end

  def handle_call({:abort_print}, _from, state) do
    case state.backend.abort_print() do
      {:ok, _} -> Tuple.insert_at(_get_status(state), 0, :reply)
      error -> error
    end
  end

  def handle_call({:resume_printer}, _from, state) do
    case state.backend.resume_printer() do
      {:ok, _} -> Tuple.insert_at(_get_status(state), 0, :reply)
      error -> error
    end
  end

  def handle_call({:reset_printer}, _from, state) do
    state.backend.reset_printer()
  end

  def handle_call({:pause_printer}, _from, state) do
    case state.backend.pause_printer() do
      {:ok, _} -> Tuple.insert_at(_get_status(state), 0, :reply)
      error -> error
    end
  end

  def handle_call({:load_filament}, from, state) do
    task = Task.async(fn ->
      :timer.sleep(1000)
      state.backend.load_filament()
    end)
    status =
      %PrinterStatus{
        idle?: false,
        state: :sending_load_filament,
        state_friendly: "Sending Load Filament",
      }
    new_state = %{state | caller: from, command_in_progress: true, task: task, status: status}
    {:noreply, new_state}
  end

  def handle_call({:send_gcode, file}, _from, state) do
    :ok = state.backend.send_gcode(file)
    status =
      %PrinterStatus{
        idle?: false,
        state: :sending_gcode,
        state_friendly: "Sending gcode",
        job_progress: 0,
      }
    new_state = %{state | command_in_progress: true, status: status}
    send_data(status)
    {:reply, :ok, new_state}
  end

  def handle_call({:send_gcode_command, line}, _from, state) do
    :ok = state.backend.send_gcode_command(line)
    {:reply, :ok, state}
  end

  def handle_call({:unload_filament}, from, state) do
    task = Task.async(fn ->
      :timer.sleep(1000)
      state.backend.unload_filament()
    end)
    status =
      %PrinterStatus{
        idle?: false,
        state: :sending_unload_filament,
        state_friendly: "Sending Unload Filament",
      }
    new_state = %{state | caller: from, command_in_progress: true, task: task, status: status}
    send_data(status)
    {:noreply, new_state}
  end

  def handle_call({:update_firmware, url, expected_sha256}, _from, state) do
    Task.async(fn ->
      Downloader.prepare_firmware(url, expected_sha256)
    end)
    status =
      %PrinterStatus{
        firmware_updating?: true,
        idle?: false,
        state: :preparing_to_update_firmware,
        state_friendly: "Firmware Update"
      }
    new_state = %{state | command_in_progress: true, status: status}
    send_data(status)
    {:reply, :ok, new_state}
  end

  def handle_info({_ref, {:firmware_downloaded, _file}}, state) do
    case state.backend.enter_dfu_mode do
      :ok ->
        Process.send_after(self(), :apply_firmware, 100)
        status = %{state.status | state: :firmware_downloaded, state_friendly: "Applying Firmware"}
        new_state = %{state | status: status}
        send_data(status)
        {:noreply, new_state}
      _error ->
        status = %{state.status | firmware_updating?: false, state: :error_no_dfu, state_friendly: "DFU Failure"}
        new_state = %{state | status: status}
        send_data(status)
        {:noreply, new_state}
    end
  end

  def handle_info({_ref, {:firmware_download_failed, _error}}, state) do
    status = %{state.status | state: :firmware_update_failed, state_friendly: "Firmware Update Failed"}
    new_state = %{state | command_in_progress: false, status: status}
    send_data(status)
    {:noreply, new_state}
  end

  def handle_info(:apply_firmware, state) do
    if state.backend.in_dfu?() do
      genserver_pid = self()
      Task.async(fn ->
        Downloader.apply_firmware(genserver_pid)
      end)
      {:noreply, state}
    else
      status = %{state.status | firmware_updating?: false, state: :firmware_update_failed, state_friendly: "DFU Failure"}
      new_state = %{state | command_in_progress: false, status: status}
      send_data(status)
      {:noreply, new_state}
    end
  end

  def handle_info({:firmware_progress, percent_complete}, state) do
    status = %{state.status | state: :firmware_update_in_progress, state_friendly: "Applying Firmware", job_progress: percent_complete}
    new_state = %{state | status: status}
    send_data(status)
    {:noreply, new_state}
  end

  def handle_info({_ref, {:firmware_progress, :complete}}, state) do
    status = %{state.status | firmware_updating?: false, state: :firmware_update_finished, state_friendly: "Update Applied"}
    new_state = %{state | command_in_progress: false, status: status}
    send_data(status)
    state.backend.connect_to_printer()
    {:noreply, new_state}
  end

  def handle_info({_ref, {:firmware_progress, :failed}}, state) do
    status = %{state.status | firmware_updating?: false, state: :firmware_update_failed, state_friendly: "Update Failed"}
    new_state = %{state | command_in_progress: false, status: status}
    send_data(status)
    {:noreply, new_state}
  end

  # send gcode failed
  def handle_info({task_pid, {:error, status}}, state = %{task: %Task{ref: task_pid}}) do
    GenServer.reply(state.caller, {:error, status})
    {:noreply, %{state | command_in_progress: false, caller: nil, task: nil}}
  end

  def handle_info({:send_gcode_update, progress}, state) do
    Logger.debug("Sending GCode Update received: #{inspect progress}")
    status =
      %PrinterStatus{
        idle?: false,
        state: :sending_gcode,
        state_friendly: "Sending gcode",
        job_progress: progress,
        extruder_actual_temperature: 0,
        extruder_target_temperature: 0
      }
    new_state = %{state | status: status}
    {:noreply, new_state}
  end

  def handle_info({:send_gcode_finished}, state) do
    Logger.debug("Sending GCode Finished received")
    {:noreply, %{state | command_in_progress: false}}
  end

  # load/unload filament
  def handle_info({task_pid, {:ok, response}}, state = %{task: %Task{ref: task_pid}}) do
    GenServer.reply(state.caller, {:ok, response})
    {:noreply, %{state | command_in_progress: false, caller: nil, task: nil}}
  end

  # task crashed
  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    Logger.debug("Task finished: #{inspect ref}")
    {:noreply, %{state | command_in_progress: false, caller: nil, task: nil}}
  end

  def handle_info(:get_status, state) do
    response =
      case _get_status(state) do
        {{:ok, status}, new_state} ->
          send_data(status)
          {:noreply, new_state}
        {_, state} ->
          {:noreply, state}
      end

    Process.send_after(self(), :get_status, 1000)

    response
  end

  defp _get_status(state = %{command_in_progress: true, status: status}) do
    timestamp = System.monotonic_time(:millisecond)
    {{:ok, status}, %{state | status: status, last_status_fetch: timestamp}}
  end

  defp _get_status(state) do
    case state.backend.get_status() do
      {:ok, status} ->
        timestamp = System.monotonic_time(:millisecond)
        {{:ok, status}, %{state | status: status, last_status_fetch: timestamp}}

      {:error, error} ->
        {{:error, error}, state}
    end
  end

  defp send_data(event_data) do
    Registry.dispatch(Registry.PrinterStatusEvents, :printer_status_event, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:printer_status_event, event_data})
      end
    end)
  end
end
