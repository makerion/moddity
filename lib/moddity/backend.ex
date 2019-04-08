defmodule Moddity.Backend do
  @moduledoc """
  This module defines the low-level behaviors that a Backend should implement
  """

  @doc """
  Gets the status from the backend printer
  """
  @callback get_status() :: {:ok, map()} | {:error, any()}

  @doc """
  Sends the load filament command to the printer
  """
  @callback load_filament() :: :ok | {:error, any()}

  @doc """
  sends the given gcode file to the printer for printing
  """
  @callback send_gcode(binary()) :: :ok | {:error, any()}

  @doc """
  Sends the unload filament command to the printer
  """
  @callback unload_filament() :: :ok | {:error, any()}
end
