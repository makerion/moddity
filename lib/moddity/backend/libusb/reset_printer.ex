defmodule Moddity.Backend.Libusb.ResetPrinter do
  @moduledoc """
  Handles Resetting the printer
  """

  require Logger

  @reset_printer_command Moddity.Backend.Libusb.Util.build_command_request_bytes(
    ~s({"transport":{"attrs":["request","twoway"],"id":3},"data":{"command":{"idx":67,"name":"Reset_printer"}}})
  )

  def transfer_reset_printer(handle) do
    Logger.debug "Sending Reset Printer, #{inspect @reset_printer_command}"
    case LibUsb.bulk_send(handle, 0x02, @reset_printer_command, 500) do
      {:ok, 0} -> :ok
      error ->
        Logger.error "Received: #{inspect error}"
        error
    end
  end
end
