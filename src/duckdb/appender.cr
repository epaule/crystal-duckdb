# Efficiently bulk-loads rows into a single DuckDB table.
#
# The appender is the fast path for loading data: it buffers rows and bypasses
# the overhead of individual `INSERT` statements. It is tied to the connection
# that created it and uses that connection's transaction context.
#
# Values are pushed with `#<<` and grouped into rows with `#row` (or the lower
# level `#begin_row` / `#end_row`). Buffered rows are sent to the database on
# `#flush` and `#close`; typically you obtain one via `Connection#appender` and
# let the block form close it for you.
#
# ```
# cnn.appender("contacts") do |appender|
#   appender.row do |row|
#     row << "Alice"
#     row << 30
#     row << true
#   end
# end
# ```
class DuckDB::Appender
  # Name of the table this appender writes to (optionally schema-qualified).
  getter table_name : String

  # Creates an appender for *table_name*, which may be `schema.table` qualified.
  #
  # Raises `DuckDB::Exception` if the name has more than one `.` separator or
  # if DuckDB cannot create the appender (e.g. the table does not exist).
  def initialize(connection : Connection, @table_name)
    tc = @table_name.split('.')
    case tc.size
    when 1
      ts = ""
      tn = tc[0]
    when 2
      ts = tc[0]
      tn = tc[1]
    else
      raise Exception.new("Invalid table name '#{@table_name}'")
    end
    state = LibDuckDB.appender_create(connection, ts, tn, out @appender)
    unless state.success?
      raise Exception.new("Failed to create appender for table '#{@table_name}'")
    end
  end

  # Appends a value to the current row.
  #
  # One overload exists per supported type (see the README datatype table).
  # The pushed value must match the column type at the current position;
  # a mismatch or other failure raises `DuckDB::Exception`. Returns `self` so
  # appends can be chained.
  def <<(value : Nil)
    check LibDuckDB.append_null(self), value
    self
  end

  # :ditto:
  def <<(value : Bool)
    check LibDuckDB.append_bool(self, value ? 1_u8 : 0_u8), value
    self
  end

  # Defines the row-lifecycle methods.
  #
  # - `begin_row` / `end_row` open and close the row currently being built.
  # - `flush` sends all buffered rows to the database.
  # - `close` flushes and then releases the appender.
  #
  # Each raises `DuckDB::Exception` on failure.
  {% for name in ["begin_row", "end_row", "flush", "close"] %}
    def {{name.id}}
      unless LibDuckDB.appender_{{name.id}}(self).success?
        raise Exception.new("Failed to {{name.id}} for table '#{@table_name}'")
      end
    end
  {% end %}

  # :ditto:
  {% for name in ["Int8", "Int16", "Int32", "Int64", "UInt8", "UInt16", "UInt32", "UInt64"] %}
    def <<(value : {{name.id}})
      check LibDuckDB.append_{{name.id.downcase}}(self, value), value
      self
    end
  {% end %}

  # :ditto:
  def <<(value : Int128)
    check LibDuckDB.append_hugeint(self, HugeIntHelper.i128_to_huge(value)), value
    self
  end

  # :ditto:
  def <<(value : Float32)
    check LibDuckDB.append_float(self, value), value
    self
  end

  # :ditto:
  def <<(value : Float64)
    check LibDuckDB.append_double(self, value), value
    self
  end

  # :ditto:
  def <<(value : String)
    check LibDuckDB.append_varchar(self, value), value
    self
  end

  # :ditto:
  def <<(value : Date)
    check LibDuckDB.append_date(self, value), value
    self
  end

  # :ditto:
  def <<(value : TimeOfDay)
    check LibDuckDB.append_time(self, value), value
    self
  end

  # :ditto:
  def <<(value : Timestamp)
    check LibDuckDB.append_timestamp(self, value), value
    self
  end

  # :ditto:
  def <<(value : Interval)
    check LibDuckDB.append_interval(self, value), value
    self
  end

  # :ditto:
  def <<(value : Bytes)
    check LibDuckDB.append_blob(self, value, value.size), value
    self
  end

  # Appends a UTC `Time` as a DuckDB `TIMESTAMP`.
  #
  # The time is converted to a `Timestamp`, which requires it to be in UTC and
  # may lose sub-microsecond precision.
  def <<(value : Time)
    self << Timestamp.new(value)
  end

  # Builds a single row: opens it, yields `self` for the value appends, then
  # closes the row.
  #
  # ```
  # appender.row do |row|
  #   row << "Alice"
  #   row << 30
  # end
  # ```
  def row(&)
    begin_row
    yield self
    end_row
  end

  # :nodoc:
  def finalize
    LibDuckDB.appender_destroy(pointerof(@appender))
  end

  # :nodoc:
  def to_unsafe
    @appender
  end

  private def check(state, value)
    unless state.success?
      raise Exception.new("Failed to append value '#{value}' for table '#{@table_name}'")
    end
  end
end
