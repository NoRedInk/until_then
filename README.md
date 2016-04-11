# UntilThen

This library tells you how many milliseconds to the next occurrence of a
scheduled event.  This is very convenient to combine with `:timer.sleep/1`
or `Process.send_after/3` as a means of repeatedly invoking some code on a
schedule and not having those invocations drift.

## Installation

Add `UntilThen` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:until_then, "~> 0.0.1"}]
end
```

Ensure that `UntilThen` is started before your application:

```elixir
def application do
  [applications: [:until_then]]
end
```

## Usage

Using `:timer.sleep/1`:

```elixir
defmodule WeekdayCheckins do
  def run_checkins do
    UntilThen.next_occurrence(:weekdays, "12:00:00") |> :timer.sleep
    checkin
    run_checkins
  end

  def checkin do
    # do the work here...
  end
end
```

Or using `Process.send_after/3`:

```elixir
defmodule WeekdayCheckins do
  def setup_checkins do
    worker = spawn(__MODULE__, :run_checkins, [ ])
    spawn(__MODULE__, :schedule_checkins, [worker])
  end

  def run_checkins do
    receive do
      {:event, scheduler} ->
        checkin
        send(scheduler, :done)
        run_checkins
    end
  end

  def checkin do
    # do the work here...
  end

  def schedule_checkins(pid) do
    delay = UntilThen.next_occurrence(:weekdays, "10:27:00")
    Process.send_after(pid, {:event, self}, delay)
    receive do
      :done -> schedule_checkins(pid)
    end
  end
end
```
