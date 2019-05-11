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
        case compare_checksums(acc) do
          :ok -> {:ok, acc}
          error -> error
        end
      error -> error
    end
  end

  defp compare_checksums(response) when byte_size(response) < 6, do: {:error, :incomplete_response}
  defp compare_checksums(response) do
    <<_::8, length_bytes::binary-size(2), length_checksum_bytes::binary-size(2), data::binary>> = response
    <<low_byte::unsigned-integer-8, high_byte::unsigned-integer-8>> = length_bytes
    length = (high_byte <<< 8) + low_byte
    checksum =
      length_bytes
      |> :binary.bin_to_list()
      |> Enum.map(fn (length_byte) -> ~~~(length_byte) end)
      |> Enum.into(<<>>, fn(byte) -> <<byte>> end)

    Logger.debug("Header: #{inspect Base.encode16(binary_part(response, 0, 5))}")
    Logger.debug("Data: #{inspect data}")

    cond do
      checksum != length_checksum_bytes ->
        Logger.debug("Checksum mismatch: Expected: #{inspect Base.encode16(length_checksum_bytes)}, Got: #{inspect Base.encode16(checksum)}")
        {:error, :checksum_mismatch}
      length != byte_size(data) ->
        Logger.debug("Length mismatch: Expected: #{inspect length}, Got: #{inspect byte_size(data)}")
        {:error, :length_mismatch}
      true ->
        :ok
    end
  end
end
