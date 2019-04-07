defmodule Moddity.PrinterStatus do
  defstruct [
    :error,
    :job_progress,
    :job_time_elapsed,
    :extruder_target_temperature,
    :extruder_temperature,
    :filament,
    :state,
    :idle?
  ]
end
