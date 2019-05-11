defmodule Moddity.Backend.Libusb.Status do
  @moduledoc """
  Handles reading printer status
  """

  import Moddity.Backend.Libusb.Util, only: [{:read_raw_status_bytes, 2}]

  require Logger

  def transfer_get_status(handle) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"status\"}}", 500) do

      read_status(handle)
    end
  end

  defp read_status(handle, error_count \\ 0)
  defp read_status(_handle, 5), do: {:error, :max_retries}
  defp read_status(handle, error_count) do
    with {:ok, data} <- read_raw_status_bytes(handle, 0x83),
         trimmed <- String.replace(data, ~r[{.*}{], "{"),
         {:ok, parsed} <- Jason.decode(trimmed) do
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
end
