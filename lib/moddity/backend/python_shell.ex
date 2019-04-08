defmodule Moddity.Backend.PythonShell do
  @moduledoc """
  This module is a shim to the python scripts that communicate with the printer.
  """

  alias Moddity.Backend

  @behaviour Backend

  @impl Backend
  def get_status do
    modt_status = Path.join([priv_dir(), "mod-t-scripts", "modt_status.py"])

    with {response, 0} <- System.cmd("python3", [modt_status]),
         {:ok, parsed_response} <- Jason.decode(response) do
      {:ok, parsed_response}
    else
      {error, 1} ->
        case Regex.match?(~r/Device not found/, error) do
          true -> {:error, "Device Not Found"}
          false -> {:error, error}
        end

      {:error, error = %Jason.DecodeError{}} ->
        {:error, "Problem parsing printer response: #{inspect(error)}"}

      error ->
        {:error, error}
    end
  end

  @impl Backend
  def load_filament do
    load_filament_script = Path.join([priv_dir(), "mod-t-scripts", "load_filament.py"])

    with {response, 0} <- System.cmd("python3", [load_filament_script]) do
      :ok
    else
      error -> {:error, error}
    end
  end

  @impl Backend
  def send_gcode(file) do
    send_gcode = Path.join([priv_dir(), "mod-t-scripts", "send_gcode.py"])

    with {response, 0} <- System.cmd("python3", [send_gcode, file]),
         {:ok, parsed_response} <- Jason.decode(response) do
      :ok
    else
      error -> {:error, error}
    end
  end

  @impl Backend
  def unload_filament do
    unload_filament_script = Path.join([priv_dir(), "mod-t-scripts", "unload_filament.py"])

    with {response, 0} <- System.cmd("python3", [unload_filament_script]) do
      :ok
    else
      error -> {:error, error}
    end
  end

  defp priv_dir do
    priv_dir = :code.priv_dir(:moddity)
  end
end
