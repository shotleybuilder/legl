defmodule Legl.MixProject do
  use Mix.Project

  @source_url "https://github.com/shotleybuilder/legl"
  @version "0.1.0"

  def project() do
    [
      app: :legl,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      env: [
        airtable_api_key: ""
      ],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.6"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:ex_prompt, "~> 0.2.0"},
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.6"},
      {:httpoison, "~> 1.6"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:erlsom, git: "https://github.com/willemdj/erlsom.git"},
      {:floki, "~> 0.34.0"},
      {:html5ever, "~> 0.14.0"},
      {:natural_order, "~> 0.2.0"},
      {:csv, "~> 3.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp description() do
    "Text to Airtable parsers for European and Middle Eastern legislation"
  end

  defp package() do
    [
      maintainers: ["Jason Woodruff"],
      files: ~w(lib priv .formatter.exs mix.exs README* readme* LICENSE*
              license* CHANGELOG* changelog* src),
      licenses: ["MPL-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "Legl",
      homepage_url: "https://legl.cc",
      source_ref: "v#{@version}",
      # canonical: "http://hexdocs.pm/legl",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
