defmodule Moddity.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Printer Events PubSub
      {Registry, keys: :duplicate, name: Registry.PrinterStatusEvents, id: Registry.PrinterStatusEvents}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Moddity.Supervisor)
  end
end
