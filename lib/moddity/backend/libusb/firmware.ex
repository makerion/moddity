defmodule Moddity.Backend.Libusb.Firmware do
  @moduledoc """
  Handles entering dfu firmware update mode
  """

  require Logger

  @enter_dfu_mode Base.decode16!("246A0095FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":7},"data":{"command":{"idx":53,"name":"Enter_dfu_mode"}}};)

  def transfer_enter_dfu_mode(handle, timeout \\ 500) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @enter_dfu_mode, timeout) do

      read_status(handle, 0, timeout)
    end
  end

  def read_status(_handle, 5, _), do: {:error, :max_retries}
  def read_status(handle, error_count, timeout) do
    with {:ok, data} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         trimmed <- String.replace(data, ~r[{.*}{], "{"),
         {:ok, parsed} <- Jason.decode(trimmed) do
      {:ok, parsed}
    else
      {:error, %Jason.DecodeError{} = error} ->
        Logger.error("Error reading status: #{inspect error}")
        read_status(handle, error_count + 1, timeout)
      error ->
        Logger.error("Error reading status: #{inspect error}")
      error
    end
  end

  def read_raw_status_bytes(handle, address, acc, timeout) do
    with {:ok, data} <- LibUsb.bulk_receive(handle, address, 64, timeout) do
      read_raw_status_bytes(handle, address, acc <> data, timeout)
    else
      {:error, :LIBUSB_ERROR_TIMEOUT} ->
        {:ok, acc}
      error ->
        error
    end
  end
end
