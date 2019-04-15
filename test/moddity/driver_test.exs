defmodule Moddity.DriverTest do
  use ExUnit.Case, async: true

  import Mox

  alias Moddity.Backend.{Mock, Simulator}
  alias Moddity.{Driver, PrinterStatus}

  doctest Moddity.Driver

  setup :verify_on_exit!

  describe "with mock backend" do
    setup do
      {:ok, mock_pid} = start_supervised({Driver, backend: Mock})
      {:ok, mock_pid: mock_pid}
    end

    test "get_status returns the status from the printer", %{mock_pid: mock_pid} do
      Mock
      |> expect(:get_status, fn -> {:ok, idle_status()} end)
      |> allow(self(), mock_pid)

      assert {:ok, idle_status()} == Driver.get_status(pid: mock_pid)
    end

    test "get_status caches printer status for one second", %{mock_pid: mock_pid} do
      Mock
      |> expect(:get_status, fn -> {:ok, idle_status()} end)
      |> expect(:get_status, fn -> {:ok, %PrinterStatus{idle?: false}} end)
      |> allow(self(), mock_pid)

      assert {:ok, idle_status()} == Driver.get_status(pid: mock_pid)
      :timer.sleep(50)
      assert {:ok, idle_status()} == Driver.get_status(pid: mock_pid)
      :timer.sleep(1000)
      assert {:ok, %PrinterStatus{idle?: false}} == Driver.get_status(pid: mock_pid)
    end

    test "when send_gcode is being sent, the printer is not idle", %{mock_pid: mock_pid} do
      Mock
      |> expect(:send_gcode, fn _file ->
        :timer.sleep(30)
        :ok
      end)
      |> allow(self(), mock_pid)

      send_gcode_task = Task.async(fn -> assert :ok = Driver.send_gcode("my_fine_print.gcode") end)
      :timer.sleep(1)
      assert {:ok, %PrinterStatus{idle?: false, state: :sending_gcode}} = Driver.get_status(pid: mock_pid)
      Task.await(send_gcode_task, 15_000)
    end
  end

  describe "with simulator backend" do
    setup do
      {:ok, _} = start_supervised({Simulator, []})
      {:ok, simulator_pid} = start_supervised({Driver, backend: Simulator})
      {:ok, simulator_pid: simulator_pid}
    end

    test "using the simulated driver works", %{simulator_pid: simulator_pid} do
      assert {:ok, %PrinterStatus{}} = Driver.get_status(pid: simulator_pid)
    end
  end

  defp idle_status do
    %PrinterStatus{idle?: true}
  end
end
