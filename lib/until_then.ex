defmodule UntilThen do
  @days ~w[monday tuesday wednesday thursday friday saturday sunday]a

  alias Calendar.{Date, DateTime, Strftime}

  def scheduled_time_zone, do: "US/Pacific"

  def next_occurrence(day, time) do
    next_occurrence(day, time, DateTime.now!(scheduled_time_zone))
  end

  def next_occurrence(day, _time, _from)
  when not (day in @days or day == :weekdays) do
    raise ArgumentError,
      "day must be #{@days |> Enum.map(&inspect/1) |> Enum.join(", ")}" <>
      ", or :weekdays"
  end
  def next_occurrence(day, time, from) do
    if time =~ ~r"\A\d{2}:\d{2}:\d{2}[-+]\d{4}\z" do
      find_next_occurrence(day, time, from, 0)
    else
      raise ArgumentError, "time must be in the format HH:MM:SS+/-ZZZZ"
    end
  end

  defp find_next_occurrence(_day, _time, _from, 10) do
    raise "An occurrence could not be found within ten days"
  end
  defp find_next_occurrence(day, time, from, offset) do
    parsed =
      with {:ok, date} <- DateTime.add(from, 60 * 60 * 24 * offset),
           {:ok, dst_date} <- DateTime.add(date, from.std_off - date.std_off),
           {:ok, date_str} <- Strftime.strftime(dst_date, "%F"),
           do: DateTime.Parse.rfc3339("#{date_str}T#{time}", scheduled_time_zone)
    if valid?(parsed, day, from) do
      to_microseconds(parsed, from)
    else
      find_next_occurrence(day, time, from, offset + 1)
    end
  end

  defp valid?(parsed, :weekdays, from) do
    @days
    |> Enum.take(5)
    |> Enum.any?(fn day -> valid?(parsed, day, from) end)
  end
  defp valid?({:ok, date}, restriction, from) when restriction in @days do
    DateTime.after?(date, from) and apply(Date, :"#{restriction}?", [date])
  end
  defp valid?(_parsed, _restriction, _from), do: false

  defp to_microseconds({:ok, to}, from) do
    {:ok, seconds, _microseconds, :after} = DateTime.diff(to, from)
    seconds * 1_000
  end
end
