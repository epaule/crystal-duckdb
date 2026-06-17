# Represents the `DATE` data type of SQL within DuckDB (a calendar day with no
# time-of-day component).
struct DuckDB::Date
  getter year : Int32
  getter month : Int32
  getter day : Int32

  # Creates a date from its components.
  #
  # Raises `ArgumentError` for an out-of-range or non-existent date.
  def initialize(@year, @month, @day)
    unless 1 <= year <= 9999 &&
           1 <= month <= 12 &&
           1 <= day <= Time.days_in_month(year, month)
      raise ArgumentError.new "Invalid date"
    end
  end

  # Creates a date from the calendar day of a `Time` (its time-of-day is ignored).
  def initialize(time : Time)
    @year = time.year
    @month = time.month
    @day = time.day
  end

  # Parses a date from a `DATE_FORMAT` string (e.g. `"1999-12-31"`).
  def initialize(string : String)
    time = Time.parse(string, DATE_FORMAT, TIMEZONE)
    @year = time.year
    @month = time.month
    @day = time.day
  end

  # Days since `Time::UNIX_EPOCH`
  def initialize(days : Int32)
    time = Time::UNIX_EPOCH + Time::Span.new(days: days)
    @year = time.year
    @month = time.month
    @day = time.day
  end

  def ==(other : self) : Bool
    @year == other.year && @month == other.month && @day == other.day
  end

  # Returns the date with an ISO 8601 format.
  def to_s(io : IO) : Nil
    io << sprintf("%04d-%02d-%02d", @year, @month, @day)
  end

  # Returns a `Time` instance with the respective date in UTC.
  def to_time
    Time.utc(@year, @month, @day)
  end

  # :nodoc:
  def to_unsafe
    date = LibDuckDB::Date.new
    date.days = (self.to_time - Time::UNIX_EPOCH).days
    date
  end
end
