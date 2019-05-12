defmodule Moddity.Backend.Libusb.Status do
  @moduledoc """
  Handles reading printer status
  """

  require Logger

  def transfer_get_status(handle, timeout \\ 500) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"status\"}}", timeout) do

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
