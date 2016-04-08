defmodule UntilThen do
  @days ~w[monday tuesday wednesday thursday friday saturday sunday]a

  @typedoc ~S"""
  An atom that is a named day of the week of the special flag :weekdays.
  """
  @type day :: :monday | :tuesday | :wednesday | :thursday | :friday |
               :saturday | :sunday | :weekdays

  alias Calendar.{Date, DateTime, Time}

  @spec scheduled_time_zone() :: String.t
  def scheduled_time_zone do
    Application.get_env(:until_then, :scheduled_time_zone, "UTC")
  end

  @spec next_occurrence(day, String.t) :: integer
  def next_occurrence(day, time) do
    next_occurrence(day, time, DateTime.now!(scheduled_time_zone))
  end

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

  @spec to_microseconds({:ok, %Calendar.DateTime{ }}, %Calendar.DateTime{ }) ::
        integer
  defp to_microseconds({:ok, to}, from) do
    {:ok, seconds, _microseconds, :after} = DateTime.diff(to, from)
    seconds * 1_000
  end
end
