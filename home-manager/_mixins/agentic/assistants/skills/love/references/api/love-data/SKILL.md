---
name: love-data
description: Provides functionality for creating and transforming data. Use this skill when working with data operations, encoding/decoding, compression, data transformation, or any data-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides functionality for creating and transforming data. Use this skill when working with data operations, encoding/decoding, compression, data transformation, or any data-related operations in LÖVE games.

## Common use cases
- Encoding and decoding data formats
- Compressing and decompressing data
- Working with binary data and byte arrays
- Performing data transformations and conversions
- Handling game save data and serialization

## Functions

- `love.data.compress` - Compresses a string or data using a specific compression algorithm.
  - `love.data.compress(container: ContainerType, format: CompressedDataFormat, rawstring: string, level: number) -> compressedData: CompressedData or string`: No description
  - `love.data.compress(container: ContainerType, format: CompressedDataFormat, data: Data, level: number) -> compressedData: CompressedData or string`: No description
- `love.data.decode` - Decode Data or a string from any of the EncodeFormats to Data or string.
  - `love.data.decode(container: ContainerType, format: EncodeFormat, sourceString: string) -> decoded: ByteData or string`: No description
  - `love.data.decode(container: ContainerType, format: EncodeFormat, sourceData: Data) -> decoded: ByteData or string`: No description
- `love.data.decompress` - Decompresses a CompressedData or previously compressed string or Data object.
  - `love.data.decompress(container: ContainerType, compressedData: CompressedData) -> decompressedData: Data or string`: No description
  - `love.data.decompress(container: ContainerType, format: CompressedDataFormat, compressedString: string) -> decompressedData: Data or string`: No description
  - `love.data.decompress(container: ContainerType, format: CompressedDataFormat, data: Data) -> decompressedData: Data or string`: No description
- `love.data.encode` - Encode Data or a string to a Data or string in one of the EncodeFormats.
  - `love.data.encode(container: ContainerType, format: EncodeFormat, sourceString: string, linelength: number) -> encoded: ByteData or string`: No description
  - `love.data.encode(container: ContainerType, format: EncodeFormat, sourceData: Data, linelength: number) -> encoded: ByteData or string`: No description
- `love.data.getPackedSize(format: string) -> size: number`: Gets the size in bytes that a given format used with love.data.pack will use. This function behaves the same as Lua 5.3's string.packsize.
- `love.data.hash` - Compute the message digest of a string using a specified hash algorithm.
  - `love.data.hash(hashFunction: HashFunction, string: string) -> rawdigest: string`: No description
  - `love.data.hash(hashFunction: HashFunction, data: Data) -> rawdigest: string`: To return the hex string representation of the hash, use love.data.encode hexDigestString = love.data.encode('string', 'hex', love.data.hash(algo, data))
- `love.data.newByteData` - Creates a new Data object containing arbitrary bytes. Data:getPointer along with LuaJIT's FFI can be used to manipulate the contents of the ByteData object after it has been created.
  - `love.data.newByteData(datastring: string) -> bytedata: ByteData`: Creates a new ByteData by copying the contents of the specified string.
  - `love.data.newByteData(Data: Data, offset: number, size: number) -> bytedata: ByteData`: Creates a new ByteData by copying from an existing Data object.
  - `love.data.newByteData(size: number) -> bytedata: ByteData`: Creates a new empty ByteData with the specific size.
- `love.data.newDataView(data: Data, offset: number, size: number) -> view: Data`: Creates a new Data referencing a subsection of an existing Data object.
- `love.data.pack(container: ContainerType, format: string, v1: number or boolean or string, ...: number or boolean or string) -> data: Data or string`: Packs (serializes) simple Lua values. This function behaves the same as Lua 5.3's string.pack.
- `love.data.unpack` - Unpacks (deserializes) a byte-string or Data into simple Lua values. This function behaves the same as Lua 5.3's string.unpack.
  - `love.data.unpack(format: string, datastring: string, pos: number) -> v1: number or boolean or string, ...: number or boolean or string, index: number`: No description
  - `love.data.unpack(format: string, data: Data, pos: number) -> v1: number or boolean or string, ...: number or boolean or string, index: number`: Unpacking integers with values greater than 2^52 is not supported, as Lua 5.1 cannot represent those values in its number type. 

## Types

- `ByteData`: Data object containing arbitrary bytes in an contiguous memory. There are currently no LÖVE functions provided for manipulating the contents of a ByteData, but Data:getPointer can be used with LuaJIT's FFI to access and write to the contents directly.

- `CompressedData`: Represents byte data compressed using a specific algorithm. love.data.decompress can be used to de-compress the data (or love.math.decompress in 0.10.2 or earlier).
  - `love.CompressedData.getFormat() -> format: CompressedDataFormat`: Gets the compression format of the CompressedData.

## Enums

- `CompressedDataFormat`: Compressed data formats.
  - `lz4`: The LZ4 compression format. Compresses and decompresses very quickly, but the compression ratio is not the best. LZ4-HC is used when compression level 9 is specified. Some benchmarks are available here.
  - `zlib`: The zlib format is DEFLATE-compressed data with a small bit of header data. Compresses relatively slowly and decompresses moderately quickly, and has a decent compression ratio.
  - `gzip`: The gzip format is DEFLATE-compressed data with a slightly larger header than zlib. Since it uses DEFLATE it has the same compression characteristics as the zlib format.
  - `deflate`: Raw DEFLATE-compressed data (no header).

- `ContainerType`: Return type of various data-returning functions.
  - `data`: Return type is ByteData.
  - `string`: Return type is string.

- `EncodeFormat`: Encoding format used to encode or decode data.
  - `base64`: Encode/decode data as base64 binary-to-text encoding.
  - `hex`: Encode/decode data as hexadecimal string.

- `HashFunction`: Hash algorithm of love.data.hash.
  - `md5`: MD5 hash algorithm (16 bytes).
  - `sha1`: SHA1 hash algorithm (20 bytes).
  - `sha224`: SHA2 hash algorithm with message digest size of 224 bits (28 bytes).
  - `sha256`: SHA2 hash algorithm with message digest size of 256 bits (32 bytes).
  - `sha384`: SHA2 hash algorithm with message digest size of 384 bits (48 bytes).
  - `sha512`: SHA2 hash algorithm with message digest size of 512 bits (64 bytes).

## Examples

### Data encoding
```lua
-- Encode data to base64
local originalData = "Hello World!"
local encoded = love.data.encode("string", "base64", originalData)
print(encoded)

-- Decode base64 data
local decoded = love.data.decode("string", "base64", encoded)
print(decoded)  -- "Hello World!"
```

### Data compression
```lua
-- Compress game data
local gameData = serializeGameState()
local compressed = love.data.compress("string", "zlib", gameData)

-- Save compressed data
love.filesystem.write("savegame.dat", compressed)
```

## Best practices
- Use appropriate encoding formats for different data types
- Consider compression for large data sets
- Handle data encoding/decoding errors gracefully
- Test data operations on target platforms
- Be mindful of memory usage with large data operations

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full data support
- **Mobile (iOS, Android)**: Full support
- **Web**: Full support
