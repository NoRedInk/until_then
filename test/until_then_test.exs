defmodule UntilThenTest do
  use ExUnit.Case, async: true

  @an_hour 60 * 60
  @a_day @an_hour * 24
  @a_week @a_day * 7
  @ms 1_000

  alias Calendar.{DateTime, Strftime}

  test "validates the scheduled day" do
    assert_raise ArgumentError, ~r{\bday\b}, fn ->
      UntilThen.next_occurrence(:weekly, "13:45:00-0700")
    end
  end

  test "validates the scheduled time" do
    assert_raise ArgumentError, ~r{\btime\b}, fn ->
      UntilThen.next_occurrence(:weekdays, "13:45 INVALID")
    end
  end

  test "schedules on a day and time" do
    {:ok, now} = DateTime.Parse.rfc3339(
      "2016-04-06T13:45:00-0700",
      UntilThen.scheduled_time_zone
    )
    an_hour_from_now = now |> DateTime.add!(@an_hour)
    day =
      an_hour_from_now
      |> Strftime.strftime!("%A")
      |> String.downcase
      |> String.to_atom
    time = an_hour_from_now |> Strftime.strftime!("%H:%M:%S%z")
    assert UntilThen.next_occurrence(day, time, now) == @an_hour * @ms
  end

  test "schedules next week if the time has already passed" do
    {:ok, now} = DateTime.Parse.rfc3339(
      "2016-04-06T13:45:00-0700",
      UntilThen.scheduled_time_zone
    )
    an_hour_from_ago = now |> DateTime.subtract!(@an_hour)
    day =
      an_hour_from_ago
      |> Strftime.strftime!("%A")
      |> String.downcase
      |> String.to_atom
    time = an_hour_from_ago |> Strftime.strftime!("%H:%M:%S%z")
    assert(
      UntilThen.next_occurrence(day, time, now) == (@a_week - @an_hour) * @ms
    )
  end

  test "schedules on weekdays at a given time" do
    {:ok, now} = DateTime.Parse.rfc3339(
      "2016-04-06T13:45:00-0700",  # Wednesday
      UntilThen.scheduled_time_zone
    )
    day = :weekdays
    time = now |> Strftime.strftime!("%H:%M:%S%z")

    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms

    now = now |> DateTime.add!(@a_day)  # Thursday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms

    now = now |> DateTime.add!(@a_day)  # Friday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * 3 * @ms

    now = now |> DateTime.add!(@a_day * 3)  # Monday
    assert UntilThen.next_occurrence(day, time, now) == @a_day * @ms
  end

  test "days aren't skipped when Daylight Savings Time begins" do
    {:ok, now} = DateTime.Parse.rfc3339(
      "2016-03-12T23:45:00-0800",  # just before a 23 hour day
      UntilThen.scheduled_time_zone
    )
    day = :sunday
    time =
      now
      |> DateTime.add!(@an_hour * 11)
      |> Strftime.strftime!("%H:%M:%S%z")
    assert UntilThen.next_occurrence(day, time, now) == @an_hour * 11 * @ms
  end
end
