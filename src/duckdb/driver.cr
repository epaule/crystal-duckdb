# `crystal-db` driver for DuckDB, registered under the `duckdb://` URI scheme.
#
# This class is not used directly; it is instantiated by `crystal-db` when a
# `duckdb://` URI is opened with `DB.open` or `DB.connect`.
class DuckDB::Driver < DB::Driver
  # Builds a `Connection` from previously parsed options.
  #
  # `crystal-db` may call `#build` more than once (e.g. to populate a pool),
  # so the parsed options are captured up front.
  class ConnectionBuilder < ::DB::ConnectionBuilder
    def initialize(@options : ::DB::Connection::Options, @duckdb_options : Connection::Options)
    end

    def build : ::DB::Connection
      Connection.new(@options, @duckdb_options)
    end
  end

  # Parses the connection URI, splitting the generic `crystal-db` pool options
  # from the DuckDB-specific options (filename and engine config params).
  def connection_builder(uri : URI) : ::DB::ConnectionBuilder
    params = HTTP::Params.parse(uri.query || "")
    ConnectionBuilder.new(connection_options(params), DuckDB::Connection::Options.from_uri(uri))
  end
end

DB.register_driver "duckdb", DuckDB::Driver
