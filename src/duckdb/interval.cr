# Represents the `INTERVAL` data type of SQL within DuckDB.
#
# DuckDB stores intervals as three independent fields — `months`, `days`, and
# `microseconds` — because the length of a month or day is not fixed. This is
# why converting to a `Time::Span` may require approximating months as days.
struct DuckDB::Interval # Shamelessly copied from PG::Interval of the Postgres driver
  getter microseconds, days, months

  # Creates an interval from its three independent fields.
  def initialize(@microseconds : Int64 = 0, @days : Int32 = 0, @months : Int32 = 0)
  end

  # Creates a `Time::Span` from this `DuckDB::Interval`.
  #
  # When `months` is non-zero, *approx_months* must give the number of days to
  # count per month; otherwise a `DuckDB::Exception` is raised because months
  # have no fixed length. Raises if the result exceeds the range of `Time::Span`.
  def to_span(approx_months : Int? = nil)
    d = days

    unless months.zero?
      if approx_months
        d += approx_months * months
      else
        raise Exception.new("Cannot represent a DuckDB::Interval contaning months as Time::Span without approximating months to days")
      end
    end

    div = microseconds.divmod(1_000_000)
    seconds = div[0]
    nanoseconds = div[1] * 1_000

    Time::Span.new(days: d, seconds: seconds, nanoseconds: nanoseconds)
  end

  # Returns the `months` field as a `Time::MonthSpan`.
  def to_month_span
    Time::MonthSpan.new(months)
  end

  # Returns the interval split into a `{Time::Span, Time::MonthSpan}` tuple, so
  # the months can be applied to a `Time` without approximation.
  def to_spans
    {
      to_span(0),
      to_month_span,
    }
  end

  def ==(other : self) : Bool
    @microseconds == other.microseconds && @days == other.days && @months == other.months
  end

  # :nodoc:
  def to_unsafe
    interval = LibDuckDB::Interval.new
    interval.months = @months
    interval.days = @days
    interval.micros = @microseconds
    interval
  end
end
