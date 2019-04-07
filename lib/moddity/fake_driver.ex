defmodule Moddity.FakeDriver do
  use GenServer

  import Process, only: [{:send_after, 3}]

  defstruct []

  @status_template %{
    "error" => 0,
    "job" => %{
      "current_gcode_number" => 0,
      "current_line_number" => 0,
      "file" => "unknown",
      "file_size" => 2345,
      "id" => "",
      "progress" => 0,
      "source" => "usb",
      "time_elapsed" => 0
    },
    "metadata" => %{"type" => "status", "version" => 1},
    "printer" => %{
      "accept_version" => 1,
      "cpu_id" => "543hhj453442345346634544",
      "firmware" => %{"name" => "RacingMoon", "version" => "0.14.0"},
      "model_name" => "MOD-t"
    },
    "status" => %{
      "build_plate" => "Unknown",
      "extruder_target_temperature" => 0.0,
      "extruder_temperature" => 162.16,
      "filament" => "OK",
      "state" => "STATE_IDLE"
    },
    "time" => %{"boot" => 516, "idle" => 0}
  }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    send_after(self(), {:update_state, :idle_state}, 4000)
    {:ok, net_failed()}
  end

  def get_status do
    GenServer.call(__MODULE__, {:get_status})
  end

  def load_filament do
    GenServer.call(__MODULE__, {:load_filament})
  end

  def send_gcode(_file) do
    GenServer.call(__MODULE__, {:send_gcode})
  end

  def unload_filament do
    GenServer.call(__MODULE__, {:unload_filament})
  end

  def handle_call({:get_status}, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call({:load_filament}, _from, state) do
    send_after(self(), {:update_state, :state_loadfil_heating}, 1_000)
    {:reply, :ok, state}
  end

  def handle_call({:send_gcode}, _from, _state) do
    send_after(self(), {:update_state, :state_job_queued}, 10_000)
    {:reply, :ok, state_file_rx()}
  end

  def handle_call({:unload_filament}, _from, state) do
    send_after(self(), {:update_state, :state_remfil_heating}, 1_000)
    {:reply, :ok, state}
  end

  def handle_info({:update_state, :idle_state}, _state) do
    {:noreply, idle_state()}
  end

  def handle_info({:update_state, :state_job_queued}, _state) do
    send_after(self(), {:update_state, :state_building}, 10_000)
    {:noreply, state_job_queued()}
  end

  def handle_info({:update_state, :state_building}, _state) do
    send_after(self(), {:update_state, :state_exec_pause_cmd}, 10_000)
    {:noreply, state_building()}
  end

  def handle_info({:update_state, :state_exec_pause_cmd}, _state) do
    send_after(self(), {:update_state, :idle_state}, 10_000)
    {:noreply, state_exec_pause_cmd()}
  end

  def handle_info({:update_state, :state_loadfil_heating}, _state) do
    send_after(self(), {:update_state, :state_loadfil_extruding}, 20_000)
    {:noreply, state_loadfil_heating()}
  end

  def handle_info({:update_state, :state_loadfil_extruding}, _state) do
    send_after(self(), {:update_state, :idle_state}, 20_000)
    {:noreply, state_loadfil_extruding()}
  end

  def handle_info({:update_state, :state_remfil_heating}, _state) do
    send_after(self(), {:update_state, :state_remfil_retracting}, 20_000)
    {:noreply, state_remfil_heating()}
  end

  def handle_info({:update_state, :state_remfil_retracting}, _state) do
    send_after(self(), {:update_state, :idle_state}, 20_000)
    {:noreply, state_remfil_retracting()}
  end

  # typically one of the known states as the machine starts, now that there's no server to contact over wifi
  defp net_failed do
    @status_template
    |> put_in(["status", "state"], "STATE_NET_FAILED")
  end

  defp idle_state do
    @status_template
  end

  # receiving file, not yet ready to print (don't press the flashing button yet)
  defp state_file_rx do
    @status_template
    |> put_in(["status", "state"], "STATE_FILE_RX")
    |> put_in(["status", "extruder_temperature"], 105.78)
  end

  # push that button!
  defp state_job_queued do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 200.0)
    |> put_in(["status", "extruder_temperature"], 105.7)
    |> put_in(["status", "state"], "STATE_JOB_QUEUED")
    |> put_in(["job", "file_size"], 1_540_647)
  end

  defp state_building do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 200.0)
    |> put_in(["status", "extruder_temperature"], 211.4)
    |> put_in(["status", "state"], "STATE_BUILDING")
    |> put_in(["job", "current_gcode_number"], 4841)
    |> put_in(["job", "current_line_number"], 4841)
    |> put_in(["job", "file_size"], 1_540_647)
    |> put_in(["job", "progress"], 9)
    |> put_in(["job", "time-elapsed"], 219)
  end

  # pause button was pressed
  defp state_exec_pause_cmd do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 210.0)
    |> put_in(["status", "state"], "STATE_EXEC_PAUSE_CMD")
    |> put_in(["job", "current_gcode_number"], 5763)
    |> put_in(["job", "current_line_number"], 5763)
    |> put_in(["job", "file_size"], 1_540_647)
    |> put_in(["job", "progress"], 10)
    |> put_in(["job", "time-elapsed"], 290)
  end

  # load filament triggered
  defp state_loadfil_heating do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 210.0)
    |> put_in(["status", "state"], "STATE_LOADFIL_HEATING")
  end

  # filament is loading
  defp state_loadfil_extruding do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 210.0)
    |> put_in(["status", "state"], "STATE_LOADFIL_EXTRUDING")
  end

  # unload filament triggered
  defp state_remfil_heating do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 210.0)
    |> put_in(["status", "state"], "STATE_REMFIL_HEATING")
  end

  # filament is retracting
  defp state_remfil_retracting do
    @status_template
    |> put_in(["status", "extruder_target_temperature"], 210.0)
    |> put_in(["status", "state"], "STATE_REMFIL_RETRACTING")
  end
end
