defmodule Moddity.Backend.Libusb.PausePrinter do
  @moduledoc """
  Handles pausing the printer
  """

  require Logger

  alias Moddity.Backend.Libusb.Status

  import Moddity.Backend.Libusb.Status, only: [{:read_raw_status_bytes, 4}]

  def transfer_abort_print(handle, timeout \\ 500) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"abort\"}}", timeout) do

      Status.transfer_get_status(handle, timeout)
    end
  end

  def transfer_pause_printer(handle, timeout \\ 500) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"pause\"}}", timeout) do

      Status.transfer_get_status(handle, timeout)
    end
  end

  def transfer_resume_printer(handle, timeout \\ 500) do
    with {:ok, _clear_buffer} <- read_raw_status_bytes(handle, 0x83, <<>>, timeout),
         {:ok, 0} <- LibUsb.bulk_send(handle, 4, "{\"metadata\":{\"version\":1,\"type\":\"unpause\"}}", timeout) do

      Status.transfer_get_status(handle, timeout)
    end
  end
end
