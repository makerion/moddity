defmodule Moddity.Backend.Libusb.SendGCode do
  @moduledoc """
  Handles the transfer complexities of sending a gcode file to the printer
  """

  require Logger

  @sequence1 Base.decode16!("246A0095FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":3},"data":{"command":{"idx":0,"name":"bio_get_version"}}};)

  def transfer_first_preamble(handle) do
    Logger.debug "Sending Sequence 1, #{inspect @sequence1}"
    with {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @sequence1, 500),
         {:ok, <<head::size(40), rest::binary>>} <- read_raw_status_bytes(handle, 0x81, <<>>),
         {:ok, message} <- Jason.decode(String.trim_trailing(rest, ";")) do

        Logger.debug "Received: #{inspect head} #{inspect message}"
        {:ok, message}
      else
        error ->
          Logger.error "Received: #{inspect error}"
          error
    end
  end

  @sequence2 Base.decode16!("248B0074FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":5},"data":{"command":{"idx":22,"name":"wifi_client_get_status","args":{"interface_t":0}}}};)

  def transfer_second_preamble(handle) do
    Logger.debug "Sending Sequence 2: #{inspect @sequence2}"
    with {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @sequence2, 500),
         {:ok, <<head::size(40), rest::binary>>} <- read_raw_status_bytes(handle, 0x81, <<>>),
         {:ok, message} <- Jason.decode(String.trim_trailing(rest, ";")) do

      Logger.debug "Received: #{inspect head} #{inspect message}"
      {:ok, message}
    else
      error ->
        Logger.error "Received: #{inspect error}"
        error
    end
  end

  @sequence3 Base.decode16!("246A0095FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":7},"data":{"command":{"idx":0,"name":"bio_get_version"}}};)

  def transfer_third_preamble(handle) do
    Logger.debug "Sending Sequence 3: #{inspect @sequence3}"
    with LibUsb.bulk_send(handle, 0x02, @sequence3, 500),
         {:ok, <<head::size(40), rest::binary>>} <- read_raw_status_bytes(handle, 0x81, <<>>),
         {:ok, message} <- Jason.decode(String.trim_trailing(rest, ";")) do

      Logger.debug "Received: #{inspect head} #{inspect rest}"
      {:ok, message}
    else
      error ->
        Logger.error "Received: #{inspect error}"
      error
    end
  end

  def transfer_file_push(handle, size, checksum) do
    header = ~s({"metadata":{"version":1,"type":"file_push"},"file_push":{"size":#{size},"adler32":#{checksum},"job_id":""}})
    Logger.debug "Sending file push header: #{inspect header}"
    case LibUsb.bulk_send(handle, 0x04, header, 500) do
      {:ok, 0} -> :ok
    end
  end

  @chunk_size 5120
  @gcode_timeout 1000

  def transfer_file(_handle, <<>>), do: :ok

  def transfer_file(handle, data) when byte_size(data) < @chunk_size do
    case LibUsb.bulk_send(handle, 0x04, data, @gcode_timeout) do
      {:ok, 0} -> :ok
      error -> error
    end
  end

  def transfer_file(handle, <<data::binary-size(@chunk_size), rest::binary>>) do
    case LibUsb.bulk_send(handle, 0x04, data, @gcode_timeout) do
      {:ok, 0} -> transfer_file(handle, rest)
      error -> error
    end
  end

  defp read_raw_status_bytes(handle, address, acc) do
    with {:ok, data} <- LibUsb.bulk_receive(handle, address, 64, 500) do
      read_raw_status_bytes(handle, address, acc <> data)
    else
      {:error, :LIBUSB_ERROR_TIMEOUT} ->
        {:ok, acc}
      error ->
        error
    end
  end
end
