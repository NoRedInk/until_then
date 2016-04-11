defmodule UntilThenTest do
  use ExUnit.Case, async: true

  @an_hour 60 * 60
  @a_day @an_hour * 24
  @a_week @a_day * 7
  @ms 1_000
  @tz "US/Pacific"  # so we can test DST changes

  alias Calendar.{DateTime, NaiveDateTime, Strftime}

  test "validates the scheduled day" do
    assert_raise ArgumentError, ~r{\bday must be\b}, fn ->
      UntilThen.next_occurrence(:weekly, "13:45:00")
    end
  end

  test "validates the scheduled time" do
    assert_raise ArgumentError, ~r{\bvalid time\b}, fn ->
      UntilThen.next_occurrence(:weekdays, "27:45:00")
    end
  end

  test "validates the scheduled time format" do
    assert_raise ArgumentError, ~r{\bHH:MM:SS\b}, fn ->
      UntilThen.next_occurrence(:weekdays, "13:45 INVALID")
    end
  end

  test "schedules on a day and time" do
    now = make_time("2016-04-06T13:45:00")
    an_hour_from_now = now |> DateTime.add!(@an_hour)
    day =
      an_hour_from_now
      |> Strftime.strftime!("%A")
      |> String.downcase
      |> String.to_atom
    time = an_hour_from_now |> Strftime.strftime!("%H:%M:%S")
    assert UntilThen.next_occurrence(day, time, now) == @an_hour * @ms
  end

  test "schedules next week if the time has already passed" do
    now = make_time("2016-04-06T13:45:00")
    an_hour_ago = now |> DateTime.subtract!(@an_hour)
    day =
      an_hour_ago
      |> Strftime.strftime!("%A")
      |> String.downcase
      |> String.to_atom
    time = an_hour_ago |> Strftime.strftime!("%H:%M:%S")
    assert(
      UntilThen.next_occurrence(day, time, now) == (@a_week - @an_hour) * @ms
    )
  end

  test "schedules on weekdays at a given time" do
    now = make_time("2016-04-06T13:45:00")  # Wednesday
    day = :weekdays
    time = now |> Strftime.strftime!("%H:%M:%S")

    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms

    now = now |> DateTime.add!(@a_day)  # Thursday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms

    now = now |> DateTime.add!(@a_day)  # Friday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * 3 * @ms

    now = now |> DateTime.add!(@a_day * 3)  # Monday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms
  end

  test "days aren't skipped when Daylight Savings Time begins" do
    now = make_time("2016-03-12T23:45:00")  # just before a 23 hour day
    day = :sunday
    time =
      now
      |> DateTime.add!(@an_hour * 11)
      |> Strftime.strftime!("%H:%M:%S")
    assert UntilThen.next_occurrence(day, time, now) == @an_hour * 11 * @ms
  end

  test "fractional seconds are rounded up" do
    now = make_time("2016-04-11T10:30:00.428797")
    day = :monday
    time =
      now
      |> DateTime.add!(5)
      |> Strftime.strftime!("%H:%M:%S")
    assert UntilThen.next_occurrence(day, time, now) == 5 * @ms
  end

  defp make_time(string, timezone \\ @tz) do
    {:ok, naive_date_time, _offset} = NaiveDateTime.Parse.iso8601(string)
    {:ok, date_time} = NaiveDateTime.to_date_time(naive_date_time, timezone)
    date_time
  end
end
