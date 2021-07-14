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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:ex_prompt, "~> 0.1.5"}
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
