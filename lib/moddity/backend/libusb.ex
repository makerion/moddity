defmodule Moddity.Backend.Libusb do
  @moduledoc """
  This module is a native implementation of the printer backend using the libusb NIF
  """

  use GenServer

  require Logger

  import Process, only: [{:send_after, 3}]

  alias Moddity.{Backend, PrinterStatus}
  alias Moddity.Backend.Libusb.SendGCode

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
    send_after(self(), :connect_to_printer, 2000)
    {:ok, %State{}}
  end

  @impl Backend
  def get_status do
    GenServer.call(__MODULE__, {:get_status})
  end

  @impl Backend
  def load_filament do
  end

  @impl Backend
  def send_gcode(file) do
    GenServer.call(__MODULE__, {:send_gcode, file})
  end

  @impl Backend
  def unload_filament do
  end

  @impl GenServer
  def handle_call({:get_status}, _caller, state = %State{handle: handle}) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, <<>>),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"status\"}}", 500),
         {:ok, modt_status} <- read_status(handle) do

      {:reply, {:ok, PrinterStatus.from_raw(modt_status)}, state}
    else
      {:error, :LIBUSB_ERROR_NO_DEVICE} ->
        send_after(self(), :connect_to_printer, 2000)
        {:reply, {:error, :no_device}, %{state | handle: nil}}
      error ->
        Logger.error("error getting status: #{inspect error}")
        {:error, error}
    end
  end

  @impl GenServer
  def handle_call({:send_gcode, file}, _caller, state = %State{handle: handle}) do
    with true <- File.exists?(file),
         {:ok, %File.Stat{size: size}} <- File.stat(file),
         {:ok, checksum} <- Adler32Checksum.compute(file),
         {:ok, _first_preamble} <- SendGCode.transfer_first_preamble(handle),
         {:ok, _second_preamble} <- SendGCode.transfer_second_preamble(handle),
         {:ok, _third_preamble} <- SendGCode.transfer_third_preamble(handle),
         :ok <- SendGCode.transfer_file_push(handle, size, checksum) do

      {:reply, :ok, state}
    else
      {:error, error} ->
        Logger.error("error getting status: #{inspect error}")
        {:error, error}
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

  defp read_status(handle, error_count \\ 0)
  defp read_status(_handle, 5), do: {:error, :max_retries}
  defp read_status(handle, error_count) do
    with {:ok, data} <- read_raw_status_bytes(handle, <<>>),
         {:ok, parsed} <- Jason.decode(data) do
      {:ok, parsed}
    else
      {:error, %Jason.DecodeError{} = error} ->
        Logger.error("Error reading status: #{inspect error}")
        read_status(handle, error_count + 1)
      error ->
        Logger.error("Error reading status: #{inspect error}")
        error
    end
  end

  defp read_raw_status_bytes(handle, acc) do
    with {:ok, data} <- LibUsb.bulk_receive(handle, 0x83, 64, 500) do
      read_raw_status_bytes(handle, acc <> data)
    else
      {:error, :LIBUSB_ERROR_TIMEOUT} ->
        {:ok, acc}
      error ->
        error
    end
  end
end
