defmodule Moddity.PrinterStatus do
  defstruct [
    :error,
    :job_progress,
    :job_time_elapsed,
    :extruder_target_temperature,
    :extruder_actual_temperature,
    :filament,
    :state,
    :state_friendly,
    :state_raw,
    :idle?
  ]

  def from_raw(raw) do
    state_raw = get_in(raw, ["status", "state"])
    state = translate_state(state_raw)

    %__MODULE__{
      state: state,
      state_friendly: to_human(state_raw),
      state_raw: get_in(raw, ["status", "state"]),
      idle?: state == :idle,
      error: raw["error"],
      job_progress: get_in(raw, ["job", "progress"]),
      extruder_target_temperature: get_in(raw, ["status", "extruder_target_temperature"]),
      extruder_actual_temperature: get_in(raw, ["status", "extruder_temperature"])
    }
  end

  defp to_human("STATE_BUILDING"), do: "Building"
  defp to_human("STATE_EXEC_PAUSE_CMD"), do: "Pausing"
  defp to_human("STATE_FILE_RX"), do: "Receiving File"
  defp to_human("STATE_HOMING_HEATING"), do: "Calibrating: Heating"
  defp to_human("STATE_HOMING_XY"), do: "Calibrating: XY"
  defp to_human("STATE_HOMING_Z_FINE"), do: "Calibrating: Z (Fine)"
  defp to_human("STATE_HOMING_Z_ROUGH"), do: "Calibrating: Z (Rough)"
  defp to_human("STATE_IDLE"), do: "Idle"
  defp to_human("STATE_JOB_CANCEL"), do: "Job Canceled"
  defp to_human("STATE_JOB_PREP"), do: "Job Prep"
  defp to_human("STATE_JOB_QUEUED"), do: "Job Queued"
  defp to_human("STATE_LOADFIL_EXTRUDING"), do: "Load Filament: Extruding"
  defp to_human("STATE_LOADFIL_HEATING"), do: "Load Filament: Heating"
  defp to_human("STATE_MECH_READY"), do: "Mech Ready"
  defp to_human("STATE_NET_FAILED"), do: "Net Failed"
  defp to_human("STATE_PAUSED"), do: "Paused"
  defp to_human("STATE_REMFIL_HEATING"), do: "Unload Filament: Heating"
  defp to_human("STATE_REMFIL_RETRACTING"), do: "Unload Filament: Retracting"
  defp to_human(state), do: "Unknown: #{state}"

  defp translate_state("STATE_BUILDING"), do: :building
  defp translate_state("STATE_EXEC_PAUSE_CMD"), do: :pausing
  defp translate_state("STATE_FILE_RX"), do: :receiving_file
  defp translate_state("STATE_HOMING_HEATING"), do: :homing_heating
  defp translate_state("STATE_HOMING_XY"), do: :homing_xy
  defp translate_state("STATE_HOMING_Z_FINE"), do: :homing_z_fine
  defp translate_state("STATE_HOMING_Z_ROUGH"), do: :homing_z_rough
  defp translate_state("STATE_IDLE"), do: :idle
  defp translate_state("STATE_JOB_CANCEL"), do: :canceled
  defp translate_state("STATE_JOB_PREP"), do: :job_prep
  defp translate_state("STATE_JOB_QUEUED"), do: :job_queued
  defp translate_state("STATE_LOADFIL_EXTRUDING"), do: :load_filament_extruding
  defp translate_state("STATE_LOADFIL_HEATING"), do: :load_filament_heating
  defp translate_state("STATE_MECH_READY"), do: :mech_ready
  defp translate_state("STATE_NET_FAILED"), do: :net_failed
  defp translate_state("STATE_PAUSED"), do: :paused
  defp translate_state("STATE_REMFIL_HEATING"), do: :unload_filament_heating
  defp translate_state("STATE_REMFIL_RETRACTING"), do: :unload_filament_retracting
  defp translate_state(_), do: :unknown
end
