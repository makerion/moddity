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

  def apply_firmware do
    file = Path.join(firmware_dir(), "modt_firmware.dfu")
    command = "dfu-util -d 2b75:0003 -a 0 -s 0x0:leave -D #{file} > /tmp/dfu-output"
    :os.cmd(String.to_charlist(command))
    :ok
  end

  defp firmware_dir do
    firmware_path = Application.get_env(:makerion_updater, :firmware_path)
    :ok = File.mkdir_p(firmware_path)
    firmware_path
  end
end
