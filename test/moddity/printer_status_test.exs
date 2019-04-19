defmodule PrinterStatusTest do
  use ExUnit.Case, async: true

  alias Moddity.PrinterStatus

  doctest PrinterStatus

  @status_template %{
    "error" => 0,
    "job" => %{
      "progress" => 9,
      "time_elapsed" => 0
    },
    "status" => %{
      "extruder_target_temperature" => 210.0,
      "extruder_temperature" => 162.16,
      "filament" => "OK",
      "state" => "STATE_IDLE"
    }
  }

  test "from_raw includes extruder information" do
    assert %PrinterStatus{
      extruder_target_temperature: 210.0,
      extruder_actual_temperature: 162.16
    } = PrinterStatus.from_raw(@status_template)
  end

  test "from_raw includes progress information" do
    assert %PrinterStatus{
      job_progress: 9
    } = PrinterStatus.from_raw(@status_template)
  end

  test "from_raw handles unknown status messages" do
    raw = put_in(@status_template, ["status", "state"], "NO_IDEA")
    assert %PrinterStatus{
      state: :unknown,
      state_friendly: "Unknown: NO_IDEA",
      idle?: false,
      error: 0
    } = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles paused" do
    raw = put_in(@status_template, ["status", "state"], "STATE_PAUSED")
    assert %PrinterStatus{
      state: :paused,
      state_friendly: "Paused",
      idle?: false,
      error: 0
    } = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles net failed" do
    raw = put_in(@status_template, ["status", "state"], "STATE_NET_FAILED")
    assert %PrinterStatus{
      state: :net_failed,
      state_friendly: "Net Failed",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles mech ready" do
    raw = put_in(@status_template, ["status", "state"], "STATE_MECH_READY")
    assert %PrinterStatus{
      state: :mech_ready,
      state_friendly: "Mech Ready",
      idle?: true,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles unload filament heating" do
    raw = put_in(@status_template, ["status", "state"], "STATE_REMFIL_HEATING")
    assert %PrinterStatus{
      state: :unload_filament_heating,
      state_friendly: "Unload Filament: Heating",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles unload filament retracting" do
    raw = put_in(@status_template, ["status", "state"], "STATE_REMFIL_RETRACTING")
    assert %PrinterStatus{
      state: :unload_filament_retracting,
      state_friendly: "Unload Filament: Retracting",
      idle?: false,
      error: 0
    } = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles load filament heating" do
    raw = put_in(@status_template, ["status", "state"], "STATE_LOADFIL_HEATING")
    assert %PrinterStatus{
      state: :load_filament_heating,
      state_friendly: "Load Filament: Heating",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles load filament extruding" do
    raw = put_in(@status_template, ["status", "state"], "STATE_LOADFIL_EXTRUDING")
    assert %PrinterStatus{
      state: :load_filament_extruding,
      state_friendly: "Load Filament: Extruding",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles job queued" do
    raw = put_in(@status_template, ["status", "state"], "STATE_JOB_QUEUED")
    assert %PrinterStatus{
      state: :job_queued,
      state_friendly: "Job Queued",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles job prep" do
    raw = put_in(@status_template, ["status", "state"], "STATE_JOB_PREP")
    assert %PrinterStatus{
      state: :job_prep,
      state_friendly: "Job Prep",
      idle?: false,
      error: 0
    } = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles job canceled" do
    raw = put_in(@status_template, ["status", "state"], "STATE_JOB_CANCEL")
    assert %PrinterStatus{
      state: :canceled,
      state_friendly: "Job Canceled",
      idle?: false,
      error: 0
    } = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles homing z fine" do
    raw = put_in(@status_template, ["status", "state"], "STATE_HOMING_Z_FINE")
    assert %PrinterStatus{
      state: :homing_z_fine,
      state_friendly: "Calibrating: Z (Fine)",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles homing z rough" do
    raw = put_in(@status_template, ["status", "state"], "STATE_HOMING_Z_ROUGH")
    assert %PrinterStatus{
      state: :homing_z_rough,
      state_friendly: "Calibrating: Z (Rough)",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles homing xy" do
    raw = put_in(@status_template, ["status", "state"], "STATE_HOMING_XY")
    assert %PrinterStatus{
      state: :homing_xy,
      state_friendly: "Calibrating: XY",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles heating" do
    raw = put_in(@status_template, ["status", "state"], "STATE_HOMING_HEATING")
    assert %PrinterStatus{
      state: :homing_heating,
      state_friendly: "Calibrating: Heating",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles receiving file" do
    raw = put_in(@status_template, ["status", "state"], "STATE_FILE_RX")
    assert %PrinterStatus{
      state: :receiving_file,
      state_friendly: "Receiving File",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles exec pause cmd" do
    raw = put_in(@status_template, ["status", "state"], "STATE_EXEC_PAUSE_CMD")
    assert %PrinterStatus{
      state: :pausing,
      state_friendly: "Pausing",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles building" do
    raw = put_in(@status_template, ["status", "state"], "STATE_BUILDING")
    assert %PrinterStatus{
      state: :building,
      state_friendly: "Building",
      idle?: false,
      error: 0} = PrinterStatus.from_raw(raw)
  end

  test "from_raw handles idle" do
    assert %PrinterStatus{
      state: :idle,
      state_friendly: "Idle",
      idle?: true,
      error: 0} = PrinterStatus.from_raw(@status_template)
  end
end
