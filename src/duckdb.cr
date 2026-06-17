require "db"
require "./duckdb/**"

# Crystal bindings for [DuckDB](https://duckdb.org/), an in-process SQL OLAP
# database, implemented as a `crystal-db` driver.
#
# Requiring this file registers the driver under the `duckdb://` URI scheme, so
# databases are opened through the standard `crystal-db` API:
#
# ```
# require "duckdb"
#
# DB.connect "duckdb://./data.db" do |cnn|
#   cnn.exec "create table contacts (name varchar, age integer)"
#   cnn.exec "insert into contacts values (?, ?)", "John Doe", 30
#   cnn.scalar "select max(age) from contacts" # => 30
# end
# ```
#
# Use `IN_MEMORY` for a transient database that is never written to disk.
module DuckDB
  # URI for an in-memory (non-persistent) database.
  #
  # The value is the percent-encoded `:memory:` marker that DuckDB expects;
  # see `Connection::Options.from_uri` for why the encoding is required.
  IN_MEMORY = "duckdb://%3Amemory%3A"

  # `Time::Format` pattern for a DuckDB `DATE` (e.g. `1999-12-31`).
  DATE_FORMAT = "%Y-%m-%d"

  # `Time::Format` pattern for a DuckDB `TIME` with a fractional (microsecond) part.
  TIME_OF_DAY_FORMAT_SUBSECOND = "%H:%M:%S.%6N"
  # `Time::Format` pattern for a DuckDB `TIME` without a fractional part.
  TIME_OF_DAY_FORMAT_SECOND = "%H:%M:%S"

  # `Time::Format` pattern for a DuckDB `TIMESTAMP` with a fractional (microsecond) part.
  TIMESTAMP_FORMAT_SUBSECOND = "#{DATE_FORMAT} #{TIME_OF_DAY_FORMAT_SUBSECOND}"
  # `Time::Format` pattern for a DuckDB `TIMESTAMP` without a fractional part.
  TIMESTAMP_FORMAT_SECOND = "#{DATE_FORMAT} #{TIME_OF_DAY_FORMAT_SECOND}"

  # Timezone assumed for every value exchanged with DuckDB.
  #
  # DuckDB has no timezone support without an extension, so all `Time` values
  # bound to or read from the database must be in UTC.
  TIMEZONE = Time::Location::UTC

  # Union of every Crystal type this driver can read from a result set or bind
  # to a statement.
  #
  # It augments `DB::Any` with the additional integer widths and the DuckDB
  # date/time structs supported by this shard.
  alias Any = DB::Any | Int8 | Int16 | UInt8 | UInt16 | UInt32 | UInt64 | DuckDB::Date | DuckDB::TimeOfDay | DuckDB::Timestamp | DuckDB::Interval | Int128
end
