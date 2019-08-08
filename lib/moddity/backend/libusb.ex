defmodule Moddity.Backend.Libusb do
  @moduledoc """
  This module is a native implementation of the printer backend using the libusb NIF
  """

  use GenServer

  require Logger

  import Process, only: [{:send_after, 3}]

  alias Moddity.{Backend, PrinterStatus}
  alias Moddity.Backend.Libusb.{Filament, GCode, PausePrinter, ResetPrinter, Status}

  @behaviour Backend

  @button_press "S1 S123"

  defmodule State do
    @moduledoc false
    defstruct handle: nil, caller: nil
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Process.flag(:trap_exit, true) # Need to release usb handle
    send_after(self(), :connect_to_printer, 2000)
    {:ok, %State{}}
  end

  @impl GenServer
  def terminate(_reason, %State{handle: nil}), do: :ok
  def terminate(_reason, %State{handle: handle}), do: LibUsb.release_handle(handle)

  @impl Backend
  def get_status do
    GenServer.call(__MODULE__, {:get_status})
  end

  @impl Backend
  def reset_printer do
    GenServer.call(__MODULE__, {:reset_printer})
  end

  @impl Backend
  def abort_print do
    GenServer.call(__MODULE__, {:abort_print})
  end

  @impl Backend
  def pause_printer do
    GenServer.call(__MODULE__, {:pause_printer})
  end

  @impl Backend
  def resume_printer do
    GenServer.call(__MODULE__, {:resume_printer})
  end

  @impl Backend
  def load_filament do
    GenServer.call(__MODULE__, {:load_filament})
  end

  @impl Backend
  def send_gcode(file) do
    GenServer.call(__MODULE__, {:send_gcode, file}, 60_000)
  end

  @impl Backend
  def send_gcode_command(line) do
    GenServer.call(__MODULE__, {:send_gcode_command, line}, 60_000)
  end

  @impl Backend
  def unload_filament do
    GenServer.call(__MODULE__, {:unload_filament})
  end

  @doc """
  Catchall to handle when the printer isn't present
  """
  @impl GenServer
  def handle_call(_, _, state = %State{handle: nil}), do: {:reply, {:error, :no_device}, state}

  @impl GenServer
  def handle_call({:get_status}, _caller, state = %State{handle: handle}) do
    case Status.transfer_get_status(handle) do
      {:ok, modt_status} ->
        {:reply, {:ok, PrinterStatus.from_raw(modt_status)}, state}
      error ->
        Logger.error("error getting status: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_call({:reset_printer}, _caller, state = %State{handle: handle}) do
    case ResetPrinter.transfer_reset_printer(handle) do
      :ok ->
        {:reply, :ok, state}
      error ->
        Logger.error("error resetting printer: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_call({:abort_print}, _caller, state = %State{handle: handle}) do
    case PausePrinter.transfer_abort_print(handle) do
      {:ok, modt_status} ->
        {:reply, {:ok, PrinterStatus.from_raw(modt_status)}, state}
      error ->
        Logger.error("error aborting: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_call({:pause_printer}, _caller, state = %State{handle: handle}) do
    case PausePrinter.transfer_pause_printer(handle) do
      {:ok, modt_status} ->
        {:reply, {:ok, PrinterStatus.from_raw(modt_status)}, state}
      error ->
        Logger.error("error pausing: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_call({:resume_printer}, _caller, state = %State{handle: handle}) do
    case PausePrinter.transfer_resume_printer(handle) do
      {:ok, modt_status} ->
        {:reply, {:ok, PrinterStatus.from_raw(modt_status)}, state}
      error ->
        Logger.error("error resuming: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_call({:load_filament}, _caller, state = %State{handle: handle}) do
    case Filament.transfer_load_filament(handle) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
      error ->
        Logger.error("Error while trying to send load filament: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @chunk_size 5120
  @impl GenServer
  def handle_call({:send_gcode, file}, caller, state = %State{handle: handle}) do
    with true <- File.exists?(file),
         {:ok, %File.Stat{size: size}} <- File.stat(file),
         {:ok, checksum} <- Adler32Checksum.compute(file),
         {:ok, _first_preamble} <- GCode.transfer_first_preamble(handle),
         {:ok, _second_preamble} <- GCode.transfer_second_preamble(handle),
         {:ok, _third_preamble} <- GCode.transfer_third_preamble(handle),
           :ok <- GCode.transfer_file_push(handle, size, checksum) do

      send_after(self(), {:transfer_file, file, size}, 10)
      {:reply, :ok, %{state | caller: caller}}
    else
      false ->
        Logger.error("File does not exist: #{inspect file}")
      {:reply, {:error, :file_does_not_exist}, state}
    {:error, error} ->
        Logger.error("error getting status: #{inspect error}")
      {error, new_state} = process_error(error, state)
      {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:send_gcode_command, line}, caller, state = %State{handle: handle}) do
    case GCode.transfer_gcode_command(handle, line) do
      :ok -> {:reply, :ok, %{state | caller: caller}}
      {:error, error} ->
        Logger.error("error sending gcode command: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unload_filament}, _caller, state = %State{handle: handle}) do
    case Filament.transfer_unload_filament(handle) do
      {:ok, response} ->
        {:reply, {:ok, response}, state}
      error ->
        Logger.error("Error while trying to send unload filament: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
    end
  end

  @impl GenServer
  def handle_info(:connect_to_printer, state = %State{}) do
    with list <- LibUsb.list_devices(),
         modt when not is_nil(modt) <- Enum.find(list, fn (device) -> device[:idVendor] == 11_125 && device[:idProduct] == 2 end),
         {:ok, handle} <- LibUsb.get_handle(modt.idVendor, modt.idProduct) do

      {:noreply, %{state | handle: handle}}
    else
      nil ->
        Logger.info("Printer not found, trying again later")
        send_after(self(), :connect_to_printer, 2000)
        {:noreply, state}
      error ->
        Logger.error("Error, trying again later. #{inspect error}")
        send_after(self(), :connect_to_printer, 2000)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:transfer_file, file, size}, state = %{caller: {caller_pid, _tag}, handle: handle}) do
    chunk_size = @chunk_size
    file
    |> File.stream!([], chunk_size)
    |> Stream.chunk_every(20)
    |> Stream.with_index()
    |> Stream.each(fn ({batch, batch_index}) ->
      progress = round((batch_index * 20 * chunk_size * 100) / size)
      send(caller_pid, {:send_gcode_update, progress})

      Enum.each(batch, fn (bytes) ->
        :ok = GCode.transfer_file_data(handle, bytes)
      end)
    end)
    |> Stream.run()

    press_button(handle)
    send(caller_pid, {:send_gcode_finished})
    {:noreply, %{state | caller: nil}}
  end

  defp press_button(handle) do
    case Status.transfer_get_status(handle) do
      {:ok, modt_status} ->
        status = PrinterStatus.from_raw(modt_status)
        case status do
          %PrinterStatus{state: :job_queued} -> GCode.transfer_gcode_command(handle, @button_press)
          _ ->
            :timer.sleep(500)
            press_button(handle)
        end
      _ ->
        :timer.sleep(500)
        press_button(handle)
    end
  end

  defp process_error(error = {:error, reason}, state = %State{handle: handle})
  when reason in [:LIBUSB_ERROR_NO_DEVICE, :LIBUSB_ERROR_PIPE, :LIBUSB_ERROR_IO, :LIBUSB_ERROR_OTHER] do

    LibUsb.release_handle(handle)
    send_after(self(), :connect_to_printer, 2000)
    {error, %{state | handle: nil}}
  end

  defp process_error(error, state = %State{handle: handle}) do
    LibUsb.release_handle(handle)
    send_after(self(), :connect_to_printer, 2000)
    {error, %{state | handle: nil}}
  end
end
