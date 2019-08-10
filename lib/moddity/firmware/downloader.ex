defmodule Moddity.Firmware.Downloader do
  @moduledoc """
  This module downloads and verifies a firmware update for the printer
  """

  require Logger

  def prepare_firmware(url, expected_sha256) do
    with file <- Path.join(firmware_dir(), "modt_firmware.dfu"),
         {:ok, %{status_code: 200, body: body}} <- HTTPoison.get(url),
         :ok <- File.write(file, body, [:binary]),
         {sha_output, 0} <- System.cmd("sha256sum", [file]),
         ^expected_sha256 <- Enum.at(String.split(sha_output, " "), 0) do

      {:firmware_downloaded, file}
    else
      error -> {:firmware_download_failed, error}
    end
  end

  def apply_firmware(caller) do
    file = Path.join(firmware_dir(), "modt_firmware.dfu")
    port = Port.open({:spawn_executable, "/usr/bin/dfu-util"}, [:stderr_to_stdout, :binary, :exit_status, args: ["-d", "2b75:0003", "-a", "0", "-s", "0x0:leave", "-D", file]])
    stream_output(port, caller)
  end

  defp stream_output(port, caller) do
    receive do
      {^port, {:data, data}} ->
        case Regex.run(~r/[ \t]([1]*[0-9]*[0-9])%/, data) do
          nil -> nil
          matches ->
            progress = Enum.at(matches, 1)
            send(caller, {:firmware_progress, progress})
        end
        stream_output(port, caller)
      {^port, {:exit_status, 0}} ->
        {:firmware_progress, :complete}
      {^port, {:exit_status, status}} ->
        Logger.error("Firmware update failed, exit code: #{inspect status}")
        {:firmware_progress, :failed}
    end
  end

  defp firmware_dir do
    firmware_path = Application.get_env(:makerion_updater, :firmware_path)
    :ok = File.mkdir_p(firmware_path)
    firmware_path
  end
end
