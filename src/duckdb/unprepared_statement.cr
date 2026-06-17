# A statement executed directly by DuckDB without preparation.
#
# Used by `crystal-db` when prepared statements are disabled (e.g. the
# `prepared_statements=false` connection option). Because it sends the SQL text
# straight to `LibDuckDB.query`, it does not support bind parameters: passing
# any args raises `DuckDB::Exception`.
class DuckDB::UnpreparedStatement < DB::Statement
  def initialize(connection, command)
    super(connection, command)
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    ResultSet.new self
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    result = perform_query_or_exec(args)
    DB::ExecResult.new result.rows_changed.to_i64, result.rows_changed.to_i64
  end

  protected def duckdb_connection
    @connection.as(Connection).to_unsafe
  end

  private def perform_query_or_exec(args : Enumerable) : LibDuckDB::Result
    raise Exception.new("Unprepared statement exec/query with args is not supported") if args.size > 0

    LibDuckDB.query(duckdb_connection, @command, out result)
    result
  end
end
