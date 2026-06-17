# Represents the `TIME` data type of SQL within DuckDB (a time of day with
# microsecond resolution and no date component).
struct DuckDB::TimeOfDay
  getter hour : Int32
  getter minute : Int32
  getter second : Int32
  getter microsecond : Int32

  # Creates a time of day from its components.
  #
  # Raises `ArgumentError` if any component is out of range.
  def initialize(@hour, @minute, @second = 0, @microsecond = 0)
    if @hour < 0 || @hour > 24 || @minute < 0 || @minute > 60 || @minute < 0 || @minute > 60 || @second < 0 || @second > 60 || @microsecond < 0 || @microsecond > 1_000_000
      raise ArgumentError.new("Invalid time of day values.")
    end
  end

  # NOTE: It raises `ArgumentError` if `time` is not in UTC.
  # NOTE: Beware the loss of precision in the fractional part (nanoseconds to microseconds)
  def initialize(time : Time)
    raise ArgumentError.new("Time is not in UTC") unless time.utc?

    @hour = time.hour
    @minute = time.minute
    @second = time.second
    @microsecond = time.nanosecond // 1000
  end

  # NOTE: It raises `ArgumentError` unless `span` is less than one day.
  # NOTE: Beware of loss of precision for the fractional part (nanoseconds to microseconds).
  def initialize(span : Time::Span)
    raise ArgumentError.new("Time span must have less than one day of duration.") if span.days >= 1
    @hour = span.hours
    @minute = span.minutes
    @second = span.seconds
    @microsecond = span.nanoseconds // 1000
  end

  # Parses a time of day from a string, with or without a fractional part
  # (e.g. `"10:11:59"` or `"10:11:59.5"`).
  def initialize(string : String)
    format = string.includes?(".") ? DuckDB::TIME_OF_DAY_FORMAT_SUBSECOND : DuckDB::TIME_OF_DAY_FORMAT_SECOND
    time = Time.parse(string, format, DuckDB::TIMEZONE)
    @hour = time.hour
    @minute = time.minute
    @second = time.second
    @microsecond = time.nanosecond // 1000
  end

  # Initialize with microseconds since 00:00:00
  # NOTE: It raises `ArgumentError` unless `microseconds` represent less than one day.
  def initialize(microseconds : Int64)
    span = Time::Span.new(nanoseconds: microseconds * 1000)
    raise ArgumentError.new("The value of microseconds must represent less than one day.") if span.days >= 1
    @hour = span.hours
    @minute = span.minutes
    @second = span.seconds
    @microsecond = span.nanoseconds // 1000
  end

  # Milliseconds part, truncated from `#microsecond`.
  def millisecond
    microsecond // 1000
  end

  # Whether there is a non-zero fractional-second part.
  def subsecond?
    @microsecond > 0
  end

  # Whether the fractional-second part is finer than one millisecond.
  def submillisecond?
    @microsecond < 1000
  end

  def ==(other : self) : Bool
    @hour == other.hour && @minute == other.minute && @second == other.second && @microsecond == other.microsecond
  end

  # Returns the time of day as a string, including a trimmed fractional part
  # when present (e.g. `"10:11:59"` or `"10:11:59.5"`).
  def to_s(io : IO) : Nil
    io << sprintf("%02d:%02d:%02d", @hour, @minute, @second)
    io << sprintf(".%06d", @microsecond).gsub(/0+$/, "") unless @microsecond.zero?
  end

  # Returns the elapsed time since midnight as a `Time::Span`.
  def to_span : Time::Span
    nanosecond = @microsecond * 1000
    Time::Span.new(hours: @hour, minutes: @minute, seconds: @second, nanoseconds: nanosecond)
  end

  # :nodoc:
  def to_unsafe
    time = LibDuckDB::Time.new
    time.micros = self.to_span.total_microseconds.to_i64
    time
  end
end
