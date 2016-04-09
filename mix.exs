defmodule UntilThen.Mixfile do
  use Mix.Project

  def project do
    [app: :until_then,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     description: description]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:calendar]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:calendar, "~> 0.14.0"},
     {:dialyze, "~> 0.2.1", only: :dev},
     {:ex_doc, "~> 0.11.4", only: :dev},
     {:earmark, "~> 0.2.1", only: :dev}]
  end

  defp package do
    %{ licenses: ["MIT"],
       maintainers: ["James Edward Gray II"],
       links: %{"GitHub" => "https://github.com/NoRedInk/until_then"}}
  end

  defp description do
    """
    This library tells you how many milliseconds to the next occurrence of a
    scheduled event.  This is very convenient to combine with `:timer.sleep/1`
    or `Process.send_after/3` as a means of repeatedly invoking some code on a
    schedule and not having those invocations drift.
    """
  end
end
