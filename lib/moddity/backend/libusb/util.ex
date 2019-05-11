defmodule Moddity.Backend.Libusb.Util do
  @moduledoc """
  Utility functions shared by libusb transfer modules
  """

  use Bitwise

  require Logger

  @doc """
  Reads a command response
  """
  def read_command_response_bytes(handle, address) do
    case read_batched(handle, address) do
      {:ok, <<header::binary-size(5), data::binary>>} ->
        Logger.debug("Header" <> Base.encode16(header))
        Logger.debug("data: #{inspect data}")
        {:ok, header, String.trim_trailing(data, ";")}
      error ->
        Logger.error("Received error: #{inspect error}")
        error
    end
  end

  @buffer_size 512
  @timeout 1000
  defp read_batched(handle, address, acc \\ <<>>) do
    case LibUsb.bulk_receive(handle, address, @buffer_size, @timeout) do
      {:ok, data} ->
        read_batched(handle, address, acc <> data)
      {:error, :LIBUSB_ERROR_TIMEOUT} ->
        <<_::8, low_byte::unsigned-integer-8, high_byte::unsigned-integer-8, __rest_of_header::16, data::binary>> = acc
        expected = (high_byte <<< 8) + low_byte
        Logger.debug("Received: #{byte_size(data)} bytes, expected: #{expected}")
        case byte_size(data) == expected do
          true -> {:ok, acc}
          false ->
            Logger.debug("Header: #{inspect Base.encode16(binary_part(acc, 0, 5))}")
            Logger.debug("Data: #{inspect data}")
            {:error, :LIBUSB_TIMEOUT}
        end
      error -> error
    end
  end
end
