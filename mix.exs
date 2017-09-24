defmodule RefInspector.Mixfile do
  use Mix.Project

  @url_github "https://github.com/elixytics/ref_inspector"

  def project do
    [ app:     :ref_inspector,
      name:    "RefInspector",
      version: "0.16.0",
      elixir:  "~> 1.3",
      deps:    deps(),

      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,

      preferred_cli_env: [
        coveralls:          :test,
        'coveralls.detail': :test,
        'coveralls.travis': :test
      ],

      description:   "Referer parser library",
      docs:          docs(),
      package:       package(),
      test_coverage: [ tool: ExCoveralls ] ]
  end

  def application do
    [ applications: [ :hackney, :logger, :poolboy, :yamerl ],
      mod:          { RefInspector.App, [] } ]
  end

  defp deps do
    [ { :ex_doc,      ">= 0.0.0", only: :dev },
      { :excoveralls, "~> 0.7",   only: :test },

      { :hackney, "~> 1.0" },
      { :poolboy, "~> 1.0" },
      { :yamerl,  "~> 0.4" } ]
  end

  defp docs do
    [ extras:     [ "CHANGELOG.md", "README.md" ],
      main:       "readme",
      source_ref: "v0.16.0",
      source_url: @url_github ]
  end

  defp package do
    %{ files:       [ "CHANGELOG.md", "LICENSE", "mix.exs", "README.md", "lib" ],
       licenses:    [ "Apache 2.0" ],
       links:       %{ "GitHub" => @url_github },
       maintainers: [ "Marc Neudert" ] }
  end
end
