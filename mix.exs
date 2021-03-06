defmodule Greenbar.Mixfile do
  use Mix.Project

  def project do
    [app: :greenbar,
     version: "0.16.0",
     elixir: "~> 1.3.1",
     erlc_options: [:debug_info, :warnings_as_errors],
     leex_options: [:warnings_as_errors],
     elixirc_paths: elixirc_paths(Mix.env),
     start_permanent: Mix.env == :prod,
     deps: deps] ++ compile_protocols(Mix.env)
  end

  def application do
    [applications: [:crypto,
                    :logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Direct dependencies
      {:piper, github: "operable/piper"},
      {:greenbar_markdown, github: "operable/greenbar_markdown"},

      # Test and Development
      {:mix_test_watch, "~> 0.2", only: [:dev, :test]},
    ]
  end

  defp compile_protocols(:prod), do: [build_embedded: true]
  defp compile_protocols(_), do: [build_embedded: false]

end
