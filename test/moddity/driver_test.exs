defmodule Moddity.DriverTest do
  use ExUnit.Case, async: true

  import Mox

  alias Moddity.Backend.Mock
  alias Moddity.Driver

  doctest Moddity.Driver

  setup :verify_on_exit!

  setup do
    {:ok, pid} = start_supervised({Driver, backend: Mock})
    {:ok, pid: pid}
  end

  test "get_status returns the status from the printer", %{pid: pid} do
    status = {:ok, %{test_status: true}}
    expect(Mock, :get_status, fn -> status end)
    allow(Mock, self(), pid)

    assert status == Driver.get_status(pid: pid)
  end

  test "when send_gcode is executing, the genserver responds to status requests appropriately", %{pid: pid} do
    status = {:ok, %{thing: :true}}

    Mock
    |> expect(:get_status, fn -> status end)
    |> expect(:send_gcode, fn _file -> :timer.sleep(10000)
      :ok end)
    |> allow(self(), pid)

    assert status == Driver.get_status(pid: pid)
    task = Task.async( fn -> assert :ok = Driver.send_gcode("whatever") end)
    assert {:ok, %{status: "IN_USE"}} == Driver.get_status(pid: pid)
    Task.await(task, 15_000)
  end
end
