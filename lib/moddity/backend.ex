defmodule Moddity.Backend do
  @doc """
  Gets the status from the backend printer
  """
  @callback get_status() :: {:ok, map()} | {:error, any()}

  @doc """
  sends the given gcode file to the printer for printing
  """
  @callback send_gcode(binary()) :: :ok | {:error, any()}
end
