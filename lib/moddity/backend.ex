defmodule Moddity.Backend do
  @moduledoc """
  This module defines the low-level behaviors that a Backend should implement
  """

  @doc """
  Sends the abort command to the printer
  """
  @callback abort_print() :: {:ok, map()} | {:error, any()}

  @doc """
  Gets the status from the backend printer
  """
  @callback get_status() :: {:ok, map()} | {:error, any()}

  @doc """
  Sends the load filament command to the printer
  """
  @callback load_filament() :: :ok | {:error, any()}

  @doc """
  Sends the pause command to the printer
  """
  @callback pause_printer() :: {:ok, map()} | {:error, any()}

  @doc """
  Sends the reset command to the printer
  """
  @callback reset_printer() :: :ok | {:error, any()}

  @doc """
  Sends the resume command to the printer
  """
  @callback resume_printer() :: {:ok, map()} | {:error, any()}

  @doc """
  sends the given gcode file to the printer for printing
  """
  @callback send_gcode(binary()) :: :ok | {:error, any()}

  @doc """
  sends the given gcode command line to the printer for printing
  """
  @callback send_gcode_command(binary()) :: :ok | {:error, any()}

  @doc """
  Sends the unload filament command to the printer
  """
  @callback unload_filament() :: :ok | {:error, any()}
end
