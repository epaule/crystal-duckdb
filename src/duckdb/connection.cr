# A connection to a DuckDB database.
#
# Obtained through the standard `crystal-db` API (`DB.connect` / `DB.open`)
# rather than instantiated directly. In addition to the inherited query/exec
# methods it exposes `#appender` for efficient bulk loading.
class DuckDB::Connection < DB::Connection
  # DuckDB-specific connection options parsed out of the connection URI.
  #
  # `filename` is the database path (or `:memory:` for an in-memory database)
  # and `config_params` holds any [DuckDB engine configuration](https://duckdb.org/docs/sql/configuration)
  # options passed as URI query params.
  record Options, filename : String, config_params : Hash(String, String) do
    # URI query keys consumed by `crystal-db` itself (pool sizing, retries,
    # etc.). They are filtered out so they are not forwarded to DuckDB as
    # engine configuration.
    CRYSTAL_DB_PARAM_KEYS = %[
      initial_pool_size
      max_pool_size
      max_idle_pool_size
      checkout_timeout
      retry_attempts
      retry_delay
      prepared_statements
    ]

    def initialize(@filename, @config_params)
    end

    # Builds `Options` from a `duckdb://` URI.
    #
    # The host and path form the database filename; every query param that is
    # not a `crystal-db` pool key (see `CRYSTAL_DB_PARAM_KEYS`) is treated as a
    # DuckDB engine configuration setting.
    def self.from_uri(uri : URI)
      raw_host = uri.host || ""
      # Crystal's URI parser wraps colon-separated hosts in IPv6 brackets,
      # so duckdb://%3Amemory%3A becomes host "[:memory:]".
      # Detect and recover the real in-memory marker.
      if raw_host == "[:memory:]"
        filename = ":memory:"
      else
        filename = URI.decode_www_form(raw_host + uri.path)
      end
      params = HTTP::Params.parse(uri.query || "")
      config_params = Hash(String, String).new
      params.each do |param|
        config_params[param[0]] = param[1] unless CRYSTAL_DB_PARAM_KEYS.includes?(param[0])
      end
      Options.new(filename, config_params)
    end
  end

  # Opens the database and establishes a connection.
  #
  # When DuckDB engine config params are present, the database is opened with a
  # config object via `open_ext`; an invalid setting raises `DuckDB::Exception`.
  def initialize(options : ::DB::Connection::Options, duckdb_options : Options)
    super(options)
    if duckdb_options.config_params.empty?
      check LibDuckDB.open(duckdb_options.filename, out @db)
    else
      LibDuckDB.create_config(out config)
      begin
        duckdb_options.config_params.each do |key, value|
          state = LibDuckDB.set_config(config, key, value)
          raise Exception.new("Configuration error for '#{key}' with value '#{value}'") unless state.success?
        end
        state = LibDuckDB.open_ext(duckdb_options.filename, out @db, config, out error_msg_p)
        raise Exception.new(String.new(error_msg_p)) unless state.success?
      ensure
        LibDuckDB.destroy_config(pointerof(config))
      end
    end
    check LibDuckDB.connect(@db, out @conn)
  end

  # Returns a new `Appender` for bulk-loading rows into *table_name*.
  #
  # The caller is responsible for flushing and closing the appender.
  def appender(table_name)
    Appender.new(self, table_name)
  end

  # Yields an `Appender` for *table_name* and closes it when the block returns,
  # flushing any buffered rows.
  #
  # ```
  # cnn.appender("contacts") do |appender|
  #   appender.row do |row|
  #     row << "Alice"
  #     row << 30
  #   end
  # end
  # ```
  def appender(table_name, &)
    appender = Appender.new(self, table_name)
    yield appender
    appender.close
  end

  def do_close
    super
    LibDuckDB.disconnect(pointerof(@conn))
    LibDuckDB.close(pointerof(@db))
  end

  def build_prepared_statement(query) : Statement
    Statement.new(self, query)
  end

  def build_unprepared_statement(query) : UnpreparedStatement
    UnpreparedStatement.new(self, query)
  end

  # :nodoc:
  def to_unsafe
    @conn
  end

  private def check(state)
    raise Exception.new("Connection error") unless state == LibDuckDB::State::Success
  end
end
