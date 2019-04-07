defmodule Moddity.Backend.PythonShell do
  def get_status do
    modt_status = Path.join([priv_dir(), "mod-t-scripts", "modt_status.py"])

    with {response, 0} <- System.cmd("python3", [modt_status]),
         {:ok, parsed_response} <- Jason.decode(response) do
      {:ok, parsed_response}
    else
      {error, 1} ->
        {:error, error}

      {:error, error} ->
        case Regex.match?(~r/Device not found/, error) do
          true -> {:error, "Device not found"}
          false -> {:error, "Unknown Error"}
        end

      error ->
        {:error, error}
    end
  end

  def load_filament do
    load_filament_script = Path.join([priv_dir(), "mod-t-scripts", "load_filament.py"])

    with {response, 0} <- System.cmd("python3", [load_filament_script]) do
      :ok
    else
      error -> {:error, error}
    end
  end

  def send_gcode(file) do
    send_gcode = Path.join([priv_dir(), "mod-t-scripts", "send_gcode.py"])

    with {response, 0} <- System.cmd("python3", [send_gcode, file]),
         {:ok, parsed_response} <- Jason.decode(response) do
      :ok
    else
      error -> {:error, error}
    end
  end

  def unload_filament do
    unload_filament_script = Path.join([priv_dir(), "mod-t-scripts", "unload_filament.py"])

    with {response, 0} <- System.cmd("python3", [unload_filament_script]) do
      IO.inspect(response)
      :ok
    else
      error -> {:error, error}
    end
  end

  defp priv_dir do
    priv_dir = :code.priv_dir(:moddity)
  end
end
