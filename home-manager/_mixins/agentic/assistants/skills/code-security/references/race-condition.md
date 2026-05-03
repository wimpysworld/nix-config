---
title: Prevent Race Conditions
impact: MEDIUM
impactDescription: Time-of-check Time-of-use (TOCTOU) vulnerabilities, insecure temporary files, data corruption
tags: security, race-condition, toctou, cwe-367, cwe-377, tempfile
---

## Prevent Race Conditions

Race conditions occur when the behavior of software depends on the timing or sequence of events that execute in an unpredictable order. Time-of-check Time-of-use (TOCTOU) vulnerabilities are a specific type of race condition where a resource's state is checked at one point in time but used at a later point, allowing an attacker to modify the resource between the check and use.

Common race condition patterns include:
- **Insecure temporary file creation**: Using functions that create predictable filenames, allowing attackers to create symlinks or replace files before they are opened
- **TOCTOU file operations**: Checking file existence/permissions then operating on the file, creating a window for manipulation
- **Hardcoded temporary paths**: Writing to shared /tmp directories without secure file creation, enabling symlink attacks

---

### Language: OCaml

#### Insecure Temporary File Creation

Using `Filename.temp_file` might lead to race conditions since the file could be altered or replaced by a symlink before being opened.

**Incorrect (vulnerable to race condition):**
```ocaml
(* ruleid:ocamllint-tempfile *)
let ofile = Filename.temp_file "test" "" in
Printf.printf "%s\n" ofile
```

**Correct (use safer alternatives):**
```ocaml
(* Use open_temp_file which returns both the filename and an open channel *)
let (filename, oc) = Filename.open_temp_file "test" "" in
Printf.fprintf oc "data\n";
close_out oc
```

**References:**
- CWE-367: Time-of-check Time-of-use (TOCTOU) Race Condition
- [OCaml Filename Module Documentation](https://v2.ocaml.org/api/Filename.html)

---

### Language: Python

#### Insecure tempfile.mktemp()

The `tempfile.mktemp()` function is explicitly marked as unsafe in Python's documentation. The file name returned may not exist when generated, but by the time you attempt to create it, another process may have created a file with that name.

**Incorrect (vulnerable to race condition):**
```python
import tempfile as tf

# ruleid: tempfile-insecure
x = tempfile.mktemp()
# ruleid: tempfile-insecure
x = tempfile.mktemp(dir="/tmp")
```

**Correct (use secure alternatives):**
```python
import tempfile

# Use NamedTemporaryFile which atomically creates and opens the file
with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
    f.write("data")
    filename = f.name

# Or use mkstemp which returns both file descriptor and name
fd, path = tempfile.mkstemp()
try:
    with os.fdopen(fd, 'w') as f:
        f.write("data")
finally:
    os.unlink(path)
```

**References:**
- CWE-377: Insecure Temporary File
- [Python tempfile Documentation](https://docs.python.org/3/library/tempfile.html)

---

#### Hardcoded /tmp Path

Using hardcoded paths in shared temporary directories like `/tmp` is insecure because other users on the system can predict and manipulate these files.

**Incorrect (hardcoded tmp path):**
```python
def test1():
    # ruleid:hardcoded-tmp-path
    f = open("/tmp/blah.txt", 'w')
    f.write("hello world")
    f.close()

def test2():
    # ruleid:hardcoded-tmp-path
    f = open("/tmp/blah/blahblah/blah.txt", 'r')
    data = f.read()
    f.close()

def test4():
    # ruleid:hardcoded-tmp-path
    with open("/tmp/blah.txt", 'r') as fin:
        data = fin.read()
```

**Correct (use tempfile module or relative paths):**
```python
def test3():
    # ok:hardcoded-tmp-path
    f = open("./tmp/blah.txt", 'w')
    f.write("hello world")
    f.close()

def test3a():
    # ok:hardcoded-tmp-path
    f = open("/var/log/something/else/tmp/blah.txt", 'w')
    f.write("hello world")
    f.close()

def test5():
    # ok:hardcoded-tmp-path
    with open("./tmp/blah.txt", 'w') as fout:
        fout.write("hello world")
```

**References:**
- CWE-377: Insecure Temporary File
- [Python tempfile.TemporaryFile Documentation](https://docs.python.org/3/library/tempfile.html#tempfile.TemporaryFile)

---

### Language: Go

#### Insecure Temporary File Creation

Creating files directly in `/tmp` without using `ioutil.TempFile` or `os.CreateTemp` is vulnerable to race conditions and symlink attacks.

**Incorrect (hardcoded tmp path):**
```go
package samples

import (
	"fmt"
	"io/ioutil"
)

func main() {
	// ruleid:bad-tmp-file-creation
	err := ioutil.WriteFile("/tmp/demo2", []byte("This is some data"), 0644)
	if err != nil {
		fmt.Println("Error while writing!")
	}
}
```

**Correct (use TempFile for atomic creation):**
```go
func main_good() {
	// ok:bad-tmp-file-creation
	err := ioutil.Tempfile("/tmp", "my_temp")
	if err != nil {
		fmt.Println("Error while writing!")
	}
}
```

**Best Practice:** Use `os.CreateTemp` (Go 1.16+) or `ioutil.TempFile` which atomically creates a new file with a unique name.

```go
import "os"

func secureTemp() error {
    // Atomically creates a file with a random suffix
    f, err := os.CreateTemp("", "prefix-*.txt")
    if err != nil {
        return err
    }
    defer f.Close()

    _, err = f.WriteString("secure data")
    return err
}
```

**References:**
- CWE-377: Insecure Temporary File
- [OWASP Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control)
- [Go ioutil.TempFile Documentation](https://pkg.go.dev/io/ioutil#TempFile)

---

## General Best Practices for Avoiding Race Conditions

### Temporary File Security

1. **Never use predictable filenames** - Always use secure random names
2. **Use atomic file creation** - Functions that create and open in one operation
3. **Set restrictive permissions** - Use mode 0600 or 0700 for temporary files/directories
4. **Use per-user temporary directories** - Consider using `$TMPDIR` or user-specific paths
5. **Clean up properly** - Delete temporary files in a finally block or defer statement

### TOCTOU Prevention

1. **Avoid check-then-use patterns** - Don't check file existence before opening
2. **Use atomic operations** - Prefer operations that check and act atomically
3. **Use file descriptors** - Once opened, operate on the descriptor not the path
4. **Lock files when needed** - Use advisory or mandatory locks for shared resources

### Language-Specific Secure Alternatives

| Language | Insecure | Secure Alternative |
|----------|----------|-------------------|
| Python | `tempfile.mktemp()` | `tempfile.NamedTemporaryFile()`, `tempfile.mkstemp()` |
| Go | `ioutil.WriteFile("/tmp/...")` | `os.CreateTemp()`, `ioutil.TempFile()` |
| OCaml | `Filename.temp_file` | `Filename.open_temp_file` |
| C | `tmpnam()`, `tempnam()` | `mkstemp()`, `mkstemps()` |
| Java | `File.createTempFile()` then open | `Files.createTempFile()` with immediate use |

**References:**
- [CWE-367: Time-of-check Time-of-use (TOCTOU) Race Condition](https://cwe.mitre.org/data/definitions/367.html)
- [CWE-377: Insecure Temporary File](https://cwe.mitre.org/data/definitions/377.html)
- [OWASP Race Conditions](https://owasp.org/www-community/vulnerabilities/Race_Conditions)
