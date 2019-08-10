defmodule Moddity.MixProject do
  use Mix.Project

  def project do
    [
      app: :moddity,
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: ~w(ex_unit mix)a,
        ignore_warnings: ".dialyzer-ignore"
      ],
      deps: deps(),
      elixir: "~> 1.9",
      elixirc_options: [warnings_as_errors: true],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        credo: :test,
        dialyzer: :test
      ],
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.1.0"
    ]
  end

  def application do
    [
      mod: {Moddity.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libusb, github: "makerion/elixir_libusb"},

      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:httpoison, "~> 1.5"},
      {:jason, "~> 1.0"},
      {:mox, "~> 0.5", only: :test}
    ]
  end
end
