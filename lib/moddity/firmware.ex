defmodule Moddity.Firmware do
  @moduledoc """
  This module is the entrypoint for firmware upgrades
  """

  use GenServer

  require Logger

  @timeout 120_000
  @default_backend Moddity.Backend.Libusb

  defstruct []

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
       task: nil
     }}
  end

  def subscribe do
    Registry.register(Registry.PrinterFirmwareEvents, :printer_firmware_event, [])
  end

  def update_firmware(url, expected_sha256, opts \\ []) do
    pid = Keyword.get(opts, :pid, __MODULE__)
    GenServer.call(pid, {:update_firmware, url, expected_sha256}, @timeout)
  end

  def handle_call({:update_firmware, _}, _from, state = %{command_in_progress: true}) do
    {:reply, {:error, :already_in_progress}, state}
  end

  def handle_call({:update_firmware, url, expected_sha256}, from, state) do
    # task = Task.async(fn ->
    #   :timer.sleep(1000)
    # end)

    file = Path.join(firmware_dir(), "modt_firmware.dfu")
    {:ok, %{status_code: 200, body: body}} = HTTPoison.get(url)
    :ok = File.write(file, body, [:binary])
    {calculated_sha256, 0} = System.cmd("sha256sum", [file])
    case calculated_sha256 do
      ^expected_sha256 ->
        :os.cmd('dfu-util -d 2b75:0003 -a 0 -s 0x0:leave -D /tmp/firmware.dfu > /tmp/dfu-output')
      _ ->
        {:error, :nope}
    end

    new_state = %{state | caller: from, command_in_progress: true, task: task, status: status}
    {:noreply, new_state}
  end

  # send gcode failed
  def handle_info({task_pid, {:error, status}}, state = %{task: %Task{ref: task_pid}}) do
    GenServer.reply(state.caller, {:error, status})
    {:noreply, %{state | command_in_progress: false, caller: nil, task: nil}}
  end

  # send gcode
  def handle_info({task_pid, :ok}, state = %{task: %Task{ref: task_pid}}) do
    GenServer.reply(state.caller, :ok)
    {:noreply, %{state | command_in_progress: false, caller: nil, task: nil}}
  end

  # task crashed
   def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
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

  defp send_data(event_data) do
    Registry.dispatch(Registry.PrinterStatusEvents, :printer_status_event, fn entries ->
      for {pid, _registered_val} <- entries do
        send(pid, {:printer_status_event, event_data})
      end
    end)
  end

  defp firmware_dir do
    firmware_path = Application.get_env(:makerion_updater, :firmware_path)
    :ok = File.mkdir_p(firmware_path)
    firmware_path
  end
end
