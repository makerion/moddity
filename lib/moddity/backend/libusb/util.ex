defmodule Moddity.Backend.Libusb.Util do
  @moduledoc """
  Utility functions shared by libusb transfer modules
  """

  @doc """
  Reads bytes in batches until the end of the message has been received
  """
  def read_raw_status_bytes(handle, address, acc \\ <<>>) do
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
