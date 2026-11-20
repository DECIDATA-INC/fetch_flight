defmodule FetchFlight.MixProject do
  use Mix.Project

  @version "0.5.0"
  @source_url "https://github.com/DECIDATA-INC/fetch_flight"

  def project do
    [
      app: :fetch_flight,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "FetchFlight",
      source_url: @source_url,
      docs: [
        main: "FetchFlight",
        source_ref: "v#{@version}",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {FetchFlight.Application, []}]
  end

  defp description do
    "Google Flights scraper — encodes queries as protobuf, fetches the results page, " <>
      "and returns structured flight data. No API key required."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:floki, "~> 0.38"},
      {:jason, "~> 1.4"},
      # Only needed by get_price_graph/1. Consumers that only call get_flights/2
      # can leave it out and skip the headless Chromium.
      {:playwright, "~> 1.49.1-alpha.2", optional: true},
      # playwright -> gun -> cowlib 2.11 does not compile on OTP 28.
      {:cowlib, "~> 2.15", override: true, optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
