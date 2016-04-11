defmodule UntilThen do
  @moduledoc ~S"""
  This library tells you how many milliseconds to the next occurrence of a
  scheduled event.  This is very convenient to combine with `:timer.sleep/1` or
  `Process.send_after/3` as a means of repeatedly invoking some code on a
  schedule and not having those invocations drift.
  """

  @days ~w[monday tuesday wednesday thursday friday saturday sunday]a

  @typedoc ~S"""
  An atom that is a named day of the week or the special flag `:weekdays`.
  """
  @type day :: :monday | :tuesday | :wednesday | :thursday | :friday |
               :saturday | :sunday | :weekdays

  alias Calendar.{Date, DateTime, Time}

  @doc ~S"""
  This function returns the time zone assumed for string times passed into
  `UntilThen.next_occurrence/2`. It defaults to `"UTC"` but it can be
  configured:

      config :until_then, scheduled_time_zone: "US/Pacific"
  """
  @spec scheduled_time_zone() :: String.t
  def scheduled_time_zone do
    Application.get_env(:until_then, :scheduled_time_zone, "UTC")
  end

  @doc ~S"""
  This function is the primary interface of this module.  You can call it
  anytime you need to know the delay until the next occurrence of a scheduled
  event.

  You pass this function a day name (like `:tuesday`) or the special flag
  `:weekdays` followed by a time string in the 24-hour format HH:MM:SS (like
  `"13:45:00"`).  It will return the number of milliseconds to the next
  occurrence of the indicated day and time.

  An example usage could be:

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
  """
  @spec next_occurrence(day, String.t) :: integer
  def next_occurrence(day, time) do
    next_occurrence(day, time, DateTime.now!(scheduled_time_zone))
  end

  @doc ~S"""
  This is just like `UntilThen.next_occurrence/2`, save that you also pass a
  `Calendar.DateTime` to be used as the point `from` which the next occurrence
  is calculated.  This is the pure function that powers the calculation and is
  used to test it, but it's generally more convenient to work with the impure
  wrapper in your own code.  However, you could use this function to vary time
  zones across calls, if needed.
  """
  @spec next_occurrence(day, String.t, %Calendar.DateTime{ }) :: integer
  def next_occurrence(day, _time, _from)
  when not (day in @days or day == :weekdays) do
    raise ArgumentError,
      "day must be #{@days |> Enum.map(&inspect/1) |> Enum.join(", ")}" <>
      ", or :weekdays"
  end
  def next_occurrence(day, time, from) do
    if time =~ ~r"\A(?:2[0-3]|[01]\d):[0-5]\d:[0-5]\d\z" do
      find_next_occurrence(day, Time.Parse.iso8601!(time), from, 0)
    else
      raise ArgumentError, "please provide a valid time in the format HH:MM:SS"
    end
  end

  # This function perform the actual search through days to locate the next
  # occurrence of the passed event.  It adjusts when it crosses Daylight Savings
  # Time boundaries, so it doesn't skip events.  When a match is found, it's
  # converted to an offset of milliseconds from the start time before it is
  # returned.  The search is limited to 10 days to prevent infinite recursion.
  @spec find_next_occurrence(day,
                             %Calendar.Time{ },
                             %Calendar.DateTime{ },
                             0..10) :: integer
  defp find_next_occurrence(_day, _time, _from, 10) do
    raise "An occurrence could not be found within ten days"
  end
  defp find_next_occurrence(day, time, from, offset) do
    occurrence =
      with {:ok, next} <- DateTime.add(from, 60 * 60 * 24 * offset),
           {:ok, next_w_dst} <- DateTime.add(next, from.std_off - next.std_off),
           date = DateTime.to_date(next_w_dst),
      do: DateTime.from_date_and_time_and_zone(date, time, from.timezone)
    if valid?(occurrence, day, from) do
      to_microseconds(occurrence, from)
    else
      find_next_occurrence(day, time, from, offset + 1)
    end
  end

  # This function validates that a passed DateTime was properly constructed,
  # is after the start time, and occurs on the indicated day.
  @spec valid?(tuple, day, %Calendar.DateTime{ }) :: :true | :false
  defp valid?(occurrence, :weekdays, from) do
    @days
    |> Enum.take(5)
    |> Enum.any?(fn day -> valid?(occurrence, day, from) end)
  end
  defp valid?({:ok, date}, restriction, from) when restriction in @days do
    DateTime.after?(date, from) and apply(Date, :"#{restriction}?", [date])
  end
  defp valid?(_occurrence, _restriction, _from), do: false

  # This function converts a later DateTime to an offset of milliseconds from
  # the start of the search.
  @spec to_microseconds({:ok, %Calendar.DateTime{ }}, %Calendar.DateTime{ }) ::
        integer
  defp to_microseconds({:ok, to}, from) do
    {:ok, seconds, microseconds, :after} = DateTime.diff(to, from)
    milliseconds = seconds * 1_000
    if microseconds > 0, do: milliseconds + 1_000, else: milliseconds
  end
end
