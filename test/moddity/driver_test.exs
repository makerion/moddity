defmodule Moddity.DriverTest do
  use ExUnit.Case, async: true

  import Mox

  alias Moddity.Backend.Mock
  alias Moddity.{Driver, PrinterStatus}

  doctest Moddity.Driver

  setup :verify_on_exit!

  setup do
    {:ok, pid} = start_supervised({Driver, backend: Mock})
    {:ok, pid: pid}
  end

  test "get_status returns the status from the printer", %{pid: pid} do
    Mock
    |> expect(:get_status, fn -> {:ok, idle_status()} end)
    |> allow(self(), pid)

    assert {:ok, idle_status()} == Driver.get_status(pid: pid)
  end

  test "get_status caches printer status for one second", %{pid: pid} do
    Mock
    |> expect(:get_status, fn -> {:ok, idle_status()} end)
    |> expect(:get_status, fn -> {:ok, %PrinterStatus{idle?: false}} end)
    |> allow(self(), pid)

    assert {:ok, idle_status()} == Driver.get_status(pid: pid)
    :timer.sleep(50)
    assert {:ok, idle_status()} == Driver.get_status(pid: pid)
    :timer.sleep(1000)
    assert {:ok, %PrinterStatus{idle?: false}} == Driver.get_status(pid: pid)
  end

  test "when send_gcode is being sent, the printer is not idle", %{pid: pid} do
    Mock
    |> expect(:send_gcode, fn _file ->
      :timer.sleep(30)
      :ok
    end)
    |> allow(self(), pid)

    send_gcode_task = Task.async(fn -> assert :ok = Driver.send_gcode("my_fine_print.gcode") end)
    :timer.sleep(1)
    assert {:ok, %PrinterStatus{idle?: false, state: :sending_gcode}} = Driver.get_status(pid: pid)
    Task.await(send_gcode_task, 15_000)
  end

  defp idle_status do
    %PrinterStatus{idle?: true}
  end
end
