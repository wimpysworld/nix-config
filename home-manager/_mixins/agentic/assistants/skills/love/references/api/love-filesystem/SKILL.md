---
name: love-filesystem
description: Provides an interface to the user's filesystem. Use this skill when working with file operations, directory management, file reading/writing, or any filesystem-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to the user's filesystem. Use this skill when working with file operations, directory management, file reading/writing, or any filesystem-related operations in LÖVE games.

## Common use cases
- Reading and writing files
- Managing directories and file paths
- Handling game save data and configuration files
- Working with compressed files and archives
- Accessing filesystem information and metadata

## Functions

- `love.filesystem.append` - Append data to an existing file.
  - `love.filesystem.append(name: string, data: string, size: number) -> success: boolean, errormsg: string`: No description
  - `love.filesystem.append(name: string, data: Data, size: number) -> success: boolean, errormsg: string`: No description
- `love.filesystem.areSymlinksEnabled() -> enable: boolean`: Gets whether love.filesystem follows symbolic links.
- `love.filesystem.createDirectory(name: string) -> success: boolean`: Recursively creates a directory. When called with 'a/b' it creates both 'a' and 'a/b', if they don't exist already.
- `love.filesystem.getAppdataDirectory() -> path: string`: Returns the application data directory (could be the same as getUserDirectory)
- `love.filesystem.getCRequirePath() -> paths: string`: Gets the filesystem paths that will be searched for c libraries when require is called. The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) Additionally, any occurrence of a double question mark ('??') will be replaced by the name passed to require and the default library extension for the platform. The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
- `love.filesystem.getDirectoryItems` - Returns a table with the names of files and subdirectories in the specified path. The table is not sorted in any way; the order is undefined. If the path passed to the function exists in the game and the save directory, it will list the files and directories from both places.
  - `love.filesystem.getDirectoryItems(dir: string) -> files: table`: No description
  - `love.filesystem.getDirectoryItems(dir: string, callback: function) -> files: table`: No description
- `love.filesystem.getIdentity() -> name: string`: Gets the write directory name for your game.  Note that this only returns the name of the folder to store your files in, not the full path.
- `love.filesystem.getInfo` - Gets information about the specified file or directory.
  - `love.filesystem.getInfo(path: string, filtertype: FileType) -> info: table`: No description
  - `love.filesystem.getInfo(path: string, info: table) -> info: table`: This variant accepts an existing table to fill in, instead of creating a new one.
  - `love.filesystem.getInfo(path: string, filtertype: FileType, info: table) -> info: table`: This variant only returns info if the item at the given path is the same file type as specified in the filtertype argument, and accepts an existing table to fill in, instead of creating a new one.
- `love.filesystem.getRealDirectory(filepath: string) -> realdir: string`: Gets the platform-specific absolute path of the directory containing a filepath. This can be used to determine whether a file is inside the save directory or the game's source .love.
- `love.filesystem.getRequirePath() -> paths: string`: Gets the filesystem paths that will be searched when require is called. The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
- `love.filesystem.getSaveDirectory() -> dir: string`: Gets the full path to the designated save directory. This can be useful if you want to use the standard io library (or something else) to read or write in the save directory.
- `love.filesystem.getSource() -> path: string`: Returns the full path to the the .love file or directory. If the game is fused to the LÖVE executable, then the executable is returned.
- `love.filesystem.getSourceBaseDirectory() -> path: string`: Returns the full path to the directory containing the .love file. If the game is fused to the LÖVE executable, then the directory containing the executable is returned. If love.filesystem.isFused is true, the path returned by this function can be passed to love.filesystem.mount, which will make the directory containing the main game (e.g. C:\Program Files\coolgame\) readable by love.filesystem.
- `love.filesystem.getUserDirectory() -> path: string`: Returns the path of the user's directory
- `love.filesystem.getWorkingDirectory() -> cwd: string`: Gets the current working directory.
- `love.filesystem.init(appname: string)`: Initializes love.filesystem, will be called internally, so should not be used explicitly.
- `love.filesystem.isFused() -> fused: boolean`: Gets whether the game is in fused mode or not. If a game is in fused mode, its save directory will be directly in the Appdata directory instead of Appdata/LOVE/. The game will also be able to load C Lua dynamic libraries which are located in the save directory. A game is in fused mode if the source .love has been fused to the executable (see Game Distribution), or if '--fused' has been given as a command-line argument when starting the game.
- `love.filesystem.lines(name: string) -> iterator: function`: Iterate over the lines in a file.
- `love.filesystem.load(name: string) -> chunk: function, errormsg: string`: Loads a Lua file (but does not run it).
- `love.filesystem.mount` - Mounts a zip file or folder in the game's save directory for reading. It is also possible to mount love.filesystem.getSourceBaseDirectory if the game is in fused mode.
  - `love.filesystem.mount(archive: string, mountpoint: string, appendToPath: boolean) -> success: boolean`: No description
  - `love.filesystem.mount(filedata: FileData, mountpoint: string, appendToPath: boolean) -> success: boolean`: Mounts the contents of the given FileData in memory. The FileData's data must contain a zipped directory structure.
  - `love.filesystem.mount(data: Data, archivename: string, mountpoint: string, appendToPath: boolean) -> success: boolean`: Mounts the contents of the given Data object in memory. The data must contain a zipped directory structure.
- `love.filesystem.newFile` - Creates a new File object.  It needs to be opened before it can be accessed.
  - `love.filesystem.newFile(filename: string) -> file: File`: Please note that this function will not return any error message (e.g. if you use an invalid filename) because it just creates the File Object. You can still check if the file is valid by using File:open which returns a boolean and an error message if something goes wrong while opening the file.
  - `love.filesystem.newFile(filename: string, mode: FileMode) -> file: File, errorstr: string`: Creates a File object and opens it for reading, writing, or appending.
- `love.filesystem.newFileData` - Creates a new FileData object from a file on disk, or from a string in memory.
  - `love.filesystem.newFileData(contents: string, name: string) -> data: FileData`: Creates a new FileData object from a string in memory.
  - `love.filesystem.newFileData(originaldata: Data, name: string) -> data: FileData`: Creates a new FileData object from a Data object in memory.
  - `love.filesystem.newFileData(filepath: string) -> data: FileData, err: string`: Creates a new FileData from a file on the storage device.
- `love.filesystem.read` - Read the contents of a file.
  - `love.filesystem.read(name: string, size: number) -> contents: string, size: number, contents: nil, error: string`: No description
  - `love.filesystem.read(container: ContainerType, name: string, size: number) -> contents: FileData or string, size: number, contents: nil, error: string`: Reads the contents of a file into either a string or a FileData object.
- `love.filesystem.remove(name: string) -> success: boolean`: Removes a file or empty directory.
- `love.filesystem.setCRequirePath(paths: string)`: Sets the filesystem paths that will be searched for c libraries when require is called. The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) Additionally, any occurrence of a double question mark ('??') will be replaced by the name passed to require and the default library extension for the platform. The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
- `love.filesystem.setIdentity` - Sets the write directory for your game.  Note that you can only set the name of the folder to store your files in, not the location.
  - `love.filesystem.setIdentity(name: string)`: No description
  - `love.filesystem.setIdentity(name: string)`: No description
- `love.filesystem.setRequirePath(paths: string)`: Sets the filesystem paths that will be searched when require is called. The paths string given to this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
- `love.filesystem.setSource(path: string)`: Sets the source of the game, where the code is present. This function can only be called once, and is normally automatically done by LÖVE.
- `love.filesystem.setSymlinksEnabled(enable: boolean)`: Sets whether love.filesystem follows symbolic links. It is enabled by default in version 0.10.0 and newer, and disabled by default in 0.9.2.
- `love.filesystem.unmount(archive: string) -> success: boolean`: Unmounts a zip file or folder previously mounted for reading with love.filesystem.mount.
- `love.filesystem.write` - Write data to a file in the save directory. If the file existed already, it will be completely replaced by the new contents.
  - `love.filesystem.write(name: string, data: string, size: number) -> success: boolean, message: string`: No description
  - `love.filesystem.write(name: string, data: Data, size: number) -> success: boolean, message: string`: If you are getting the error message 'Could not set write directory', try setting the save directory. This is done either with love.filesystem.setIdentity or by setting the identity field in love.conf. '''Writing to multiple lines''': In Windows, some text editors (e.g. Notepad) only treat CRLF ('\r\n') as a new line.

## Types

- `DroppedFile`: Represents a file dropped onto the window. Note that the DroppedFile type can only be obtained from love.filedropped callback, and can't be constructed manually by the user.

- `File`: Represents a file on the filesystem. A function that takes a file path can also take a File.
  - `love.File.close() -> success: boolean`: Closes a File.
  - `love.File.flush() -> success: boolean, err: string`: Flushes any buffered written data in the file to the disk.
  - `love.File.getBuffer() -> mode: BufferMode, size: number`: Gets the buffer mode of a file.
  - `love.File.getFilename() -> filename: string`: Gets the filename that the File object was created with. If the file object originated from the love.filedropped callback, the filename will be the full platform-dependent file path.
  - `love.File.getMode() -> mode: FileMode`: Gets the FileMode the file has been opened with.
  - `love.File.getSize() -> size: number`: Returns the file size.
  - `love.File.isEOF() -> eof: boolean`: Gets whether end-of-file has been reached.
  - `love.File.isOpen() -> open: boolean`: Gets whether the file is open.
  - `love.File.lines() -> iterator: function`: Iterate over all the lines in a file.
  - `love.File.open(mode: FileMode) -> ok: boolean, err: string`: Open the file for write, read or append.
  - `love.File.read(bytes: number) -> contents: string, size: number`: Read a number of bytes from a file.
  - `love.File.seek(pos: number) -> success: boolean`: Seek to a position in a file
  - `love.File.setBuffer(mode: BufferMode, size: number) -> success: boolean, errorstr: string`: Sets the buffer mode for a file opened for writing or appending. Files with buffering enabled will not write data to the disk until the buffer size limit is reached, depending on the buffer mode. File:flush will force any buffered data to be written to the disk.
  - `love.File.tell() -> pos: number`: Returns the position in the file.
  - `love.File.write(data: string, size: number) -> success: boolean, err: string`: Write data to a file.

- `FileData`: Data representing the contents of a file.
  - `love.FileData.getExtension() -> ext: string`: Gets the extension of the FileData.
  - `love.FileData.getFilename() -> name: string`: Gets the filename of the FileData.

## Enums

- `BufferMode`: Buffer modes for File objects.
  - `none`: No buffering. The result of write and append operations appears immediately.
  - `line`: Line buffering. Write and append operations are buffered until a newline is output or the buffer size limit is reached.
  - `full`: Full buffering. Write and append operations are always buffered until the buffer size limit is reached.

- `FileDecoder`: How to decode a given FileData.
  - `file`: The data is unencoded.
  - `base64`: The data is base64-encoded.

- `FileMode`: The different modes you can open a File in.
  - `r`: Open a file for read.
  - `w`: Open a file for write.
  - `a`: Open a file for append.
  - `c`: Do not open a file (represents a closed file.)

- `FileType`: The type of a file.
  - `file`: Regular file.
  - `directory`: Directory.
  - `symlink`: Symbolic link.
  - `other`: Something completely different like a device.

## Examples

### Reading a file
```lua
-- Read the contents of a file
local content = love.filesystem.read("data.txt")
print(content)
```

### Writing to a file
```lua
-- Write data to a file
local success = love.filesystem.write("savegame.dat", gameData)
if success then
  print("Game saved successfully!")
end
```

## Best practices
- Use love.filesystem for all file operations to ensure cross-platform compatibility
- Handle file operations in love.load() or during non-critical game moments
- Always check if files exist before attempting to read them
- Use appropriate file formats for different data types
- Be mindful of filesystem permissions, especially on mobile platforms

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full filesystem support
- **Mobile (iOS, Android)**: Limited to sandboxed storage, some restrictions apply
- **Web**: Very limited filesystem access, mostly read-only operations
