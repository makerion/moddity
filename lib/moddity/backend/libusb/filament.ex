defmodule Moddity.Backend.Libusb.Filament do
  @moduledoc """
  Transfers load and unload filament commands
  """

  import Moddity.Backend.Libusb.Util, only: [{:read_raw_status_bytes, 2}]

  require Logger

  @load_filament Base.decode16!("24690096FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":9},"data":{"command":{"idx":52,"name":"load_initiate"}}};)

  def transfer_load_filament(handle) do
    Logger.debug "Sending Load Filament, #{inspect @load_filament}"
    with {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @load_filament, 500),
         {:ok, <<head::size(40), rest::binary>>} <- read_raw_status_bytes(handle, 0x81),
         {:ok, message} <- Jason.decode(String.trim_trailing(rest, ";")) do

      Logger.debug "Received: #{inspect head} #{inspect message}"
      {:ok, message}
    else
      error ->
        Logger.error "Received: #{inspect error}"
        error
    end
  end

  @unload_filament Base.decode16!("246C0093FF") <>
    ~s({"transport":{"attrs":["request","twoway"],"id":11},"data":{"command":{"idx":51,"name":"unload_initiate"}}};)

  def transfer_unload_filament(handle) do
    Logger.debug "Sending Unload Filament, #{inspect @unload_filament}"
    with {:ok, 0} <- LibUsb.bulk_send(handle, 0x02, @unload_filament, 500),
         {:ok, <<head::size(40), rest::binary>>} <- read_raw_status_bytes(handle, 0x81),
         {:ok, message} <- Jason.decode(String.trim_trailing(rest, ";")) do

      Logger.debug "Received: #{inspect head} #{inspect message}"
      {:ok, message}
    else
      error ->
        Logger.error "Received: #{inspect error}"
        error
    end
  end

end
