defmodule Moddity.Backend.Libusb do
  @moduledoc """
  This module is a native implementation of the printer backend using the libusb NIF
  """

  use GenServer

  require Logger

  import Process, only: [{:send_after, 3}]

  alias Moddity.{Backend, PrinterStatus}
  alias Moddity.Backend.Libusb.{Filament, GCode, Status}

  @behaviour Backend

  defmodule State do
    @moduledoc false
    defstruct handle: nil
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

  def crash() do
    GenServer.call(__MODULE__, {:crash})
  end

  def handle_info({:crash}, _sender, _state), do: :ohno

  @impl Backend
  def get_status do
    GenServer.call(__MODULE__, {:get_status})
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

  @impl GenServer
  def handle_call({:send_gcode, file}, _caller, state = %State{handle: handle}) do
    with true <- File.exists?(file),
         {:ok, %File.Stat{size: size}} <- File.stat(file),
         {:ok, checksum} <- Adler32Checksum.compute(file),
         {:ok, _first_preamble} <- GCode.transfer_first_preamble(handle),
         {:ok, _second_preamble} <- GCode.transfer_second_preamble(handle),
         {:ok, _third_preamble} <- GCode.transfer_third_preamble(handle),
         :ok <- GCode.transfer_file_push(handle, size, checksum),
         {:ok, gcode} <- File.read(file),
         :ok <- GCode.transfer_file(handle, gcode) do

      {:reply, :ok, state}
    else
      {:error, error} ->
        Logger.error("error getting status: #{inspect error}")
        {error, new_state} = process_error(error, state)
        {:reply, error, new_state}
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
