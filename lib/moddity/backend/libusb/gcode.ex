defmodule Moddity.Backend.Libusb.GCode do
  @moduledoc """
  Handles the transfer complexities of sending a gcode file to the printer
  """

  import Moddity.Backend.Libusb.Util, only: [{:build_command_request_bytes, 1}, {:read_command_response_bytes, 2}]

  require Logger

  def transfer_gcode_command(handle, line) do
    gcode_line_array = Enum.join(String.to_charlist(line) ++ [0], ",")
    command = ~s({"transport":{"attrs":["request","twoway"],"id":47},"data":{"command":{"idx":5,"name":"gcode_process_command","args":{"command":[#{gcode_line_array}]}}}})

    bytes = build_command_request_bytes(command)
    case LibUsb.bulk_send(handle, 0x02, bytes, 500) do
      {:ok, 0} -> :ok
      error ->
        Logger.error "Received: #{inspect error}"
        error
    end
  end

  @sequence1 Base.decode16!("246A0095FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":3},"data":{"command":{"idx":0,"name":"bio_get_version"}}};)

  def transfer_first_preamble(handle) do
    Logger.debug "Sending Sequence 1, #{inspect @sequence1}"
    with {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @sequence1, 500),
         {:ok, header, data} <- read_command_response_bytes(handle, 0x81),
         {:ok, message} <- Jason.decode(data) do

        Logger.debug "Received: #{inspect Base.encode16(header)} #{inspect message}"
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
         {:ok, header, data} <- read_command_response_bytes(handle, 0x81),
         {:ok, message} <- Jason.decode(data) do

      Logger.debug "Received: #{inspect Base.encode16(header)} #{inspect message}"
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
         {:ok, header, data} <- read_command_response_bytes(handle, 0x81),
         {:ok, message} <- Jason.decode(data) do

      Logger.debug "Received: #{inspect Base.encode16(header)} #{inspect message}"
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

  @gcode_timeout 1000
  def transfer_file_data(handle, data) do
    case LibUsb.bulk_send(handle, 0x04, data, @gcode_timeout) do
      {:ok, 0} -> :ok
      error -> error
    end
  end
end
