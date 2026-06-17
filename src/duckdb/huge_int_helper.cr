module DuckDB
  # Converts between Crystal's native `Int128` and DuckDB's `HUGEINT`, which the
  # C API exposes as a split `{upper : Int64, lower : UInt64}` struct.
  #
  # The two halves are round-tripped through a 16-byte big-endian buffer so the
  # 128-bit value is reassembled with the correct sign and magnitude.
  module HugeIntHelper
    private FORMAT = IO::ByteFormat::BigEndian

    # Combines a DuckDB `HugeInt`'s upper/lower halves into an `Int128`.
    def self.huge_to_i128(value : LibDuckDB::HugeInt) : Int128
      aux_io = IO::Memory.new(16)
      aux_io.write_bytes(value.upper, FORMAT)
      aux_io.write_bytes(value.lower, FORMAT)
      aux_io.rewind
      Int128.from_io(aux_io, FORMAT)
    end

    # Splits an `Int128` into a DuckDB `HugeInt`'s upper/lower halves.
    def self.i128_to_huge(value : Int128) : LibDuckDB::HugeInt
      aux_io = IO::Memory.new(16)
      value.to_io(aux_io, FORMAT)
      aux_io.rewind
      result = LibDuckDB::HugeInt.new
      result.upper = Int64.from_io(aux_io, FORMAT)
      result.lower = UInt64.from_io(aux_io, FORMAT)
      result
    end
  end
end
