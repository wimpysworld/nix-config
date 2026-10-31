import json
import os
import stat
import sys
import uuid

REGISTRY = "mcp-servers.json"
BACKUP = "mcp-servers.json.pre-mcporter.bak"


def open_directory(path):
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in os.path.abspath(path).split("/"):
            if not part:
                continue
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Unsafe data directory")
        return fd
    except BaseException:
        os.close(fd)
        raise


def check_file(fd):
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        raise ValueError("Unsafe registry file")
    return info


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate field")
        result[key] = value
    return result


def reject_constant(_):
    raise ValueError("Invalid number")


def write_temporary(directory, content):
    name = ".mcp-cli-" + uuid.uuid4().hex
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=directory)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        os.unlink(name, dir_fd=directory)
        raise
    return name


def migrate(path):
    try:
        directory = open_directory(path)
    except FileNotFoundError:
        return
    try:
        try:
            fd = os.open(REGISTRY, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        except FileNotFoundError:
            return
        with os.fdopen(fd, "rb") as source:
            original = check_file(source.fileno())
            content = source.read()
            data = json.loads(content, object_pairs_hook=unique_object, parse_constant=reject_constant)
            if not isinstance(data, dict) or not isinstance(data.get("servers", {}), dict):
                raise ValueError("Invalid registry")
            servers = data.get("servers", {})
            for server in servers.values():
                if not isinstance(server, dict) or not isinstance(server.get("enabled", True), bool):
                    raise ValueError("Invalid server")
            try:
                backup_fd = os.open(BACKUP, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
            except FileNotFoundError:
                backup_fd = None
            if backup_fd is not None:
                with os.fdopen(backup_fd, "rb") as backup:
                    info = check_file(backup.fileno())
                    if stat.S_IMODE(info.st_mode) != 0o600:
                        raise ValueError("Unsafe backup permissions")
            if all(server.get("enabled") is False for server in servers.values()):
                os.fchmod(source.fileno(), 0o600)
                return
            if backup_fd is None:
                temporary = write_temporary(directory, content)
                try:
                    os.link(temporary, BACKUP, src_dir_fd=directory, dst_dir_fd=directory, follow_symlinks=False)
                    os.fsync(directory)
                finally:
                    os.unlink(temporary, dir_fd=directory)
            for server in servers.values():
                server["enabled"] = False
            temporary = write_temporary(directory, (json.dumps(data, indent=2, ensure_ascii=True) + "\n").encode())
            try:
                current = os.stat(REGISTRY, dir_fd=directory, follow_symlinks=False)
                if (current.st_dev, current.st_ino, current.st_mtime_ns, current.st_size) != (
                    original.st_dev, original.st_ino, original.st_mtime_ns, original.st_size
                ):
                    raise ValueError("Registry changed during migration")
                os.replace(temporary, REGISTRY, src_dir_fd=directory, dst_dir_fd=directory)
                temporary = None
                os.fsync(directory)
            finally:
                if temporary is not None:
                    os.unlink(temporary, dir_fd=directory)
    finally:
        os.close(directory)


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Expected data directory")
        migrate(sys.argv[1])
    except Exception:
        print("Moltis: MCP registry migration failed. Gateway startup stopped.", file=sys.stderr)
        sys.exit(1)
