defmodule Moddity do
  @moduledoc """
  Documentation for Moddity.
  """

  def send_gcode do
    priv_dir = :code.priv_dir(:moddity)
    send_gcode = Path.join([priv_dir, "mod-t-scripts", "send_gcode.py"])
    gcode_file = Path.join([priv_dir, "mod-t-scripts", "testPrint.gcode"])
    System.cmd("python3", [send_gcode, gcode_file])
  end

  def get_status do
    priv_dir = :code.priv_dir(:moddity)
    modt_status = Path.join([priv_dir, "mod-t-scripts", "modt_status.py"])
    System.cmd("python3", [modt_status])
  end
end
