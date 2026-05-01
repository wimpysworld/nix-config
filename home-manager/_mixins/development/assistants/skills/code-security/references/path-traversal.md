---
title: Prevent Path Traversal
impact: CRITICAL
impactDescription: Arbitrary file access, information disclosure, file manipulation
tags: security, path-traversal, cwe-22, cwe-23, cwe-73, cwe-98
---

## Prevent Path Traversal

Path traversal occurs when user input is used to construct file paths without proper validation, allowing attackers to access files outside intended directories using sequences like "../". This can lead to sensitive data exposure, arbitrary file reads/writes, and system compromise.

---

### Language: Python

#### open() Path Traversal

**Incorrect (vulnerable to path traversal):**
```python
def unsafe(request):
    filename = request.POST.get('filename')
    f = open(filename, 'r')
    data = f.read()
    f.close()
    return HttpResponse(data)
```

**Correct (static path):**
```python
def safe(request):
    filename = "/tmp/data.txt"
    f = open(filename)
    data = f.read()
    f.close()
    return HttpResponse(data)
```

**References:**
- CWE-22: Path Traversal
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)

---

### Language: JavaScript/Node.js

#### Non-Literal fs Filename

**Incorrect (vulnerable to path traversal):**
```javascript
const fs = require('fs');

function readUserFile(fileName) {
  fs.readFile(fileName, (err, data) => {
    if (err) throw err;
    console.log(data);
  });
}
```

**Correct (safe with literal path):**
```javascript
const fs = require('fs');

function readConfigFile() {
  fs.readFile('config/settings.json', (err, data) => {
    if (err) throw err;
    console.log(data);
  });
}
```

**References:**
- CWE-22: Path Traversal
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)

---

#### path.join/path.resolve Traversal

**Incorrect (vulnerable to path traversal):**
```javascript
const path = require('path');

function getFile(entry) {
  var extractPath = path.join(opts.path, entry.path);
  return extractFile(extractPath);
}
```

**Correct (path sanitized):**
```javascript
const path = require('path');

function getFileSafe(req, res) {
  let somePath = req.body.path;
  somePath = somePath.replace(/^(\.\.(\/|\\|$))+/, '');
  return path.join(opts.path, somePath);
}
```

**References:**
- CWE-22: Path Traversal
- [OWASP Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal)

---

### Language: Java

#### HttpServlet Path Traversal

**Incorrect (vulnerable to path traversal):**
```java
public class FileServlet extends HttpServlet {
    public void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String image = request.getParameter("image");
        File file = new File("static/images/", image);
        if (!file.exists()) {
            response.sendError(404);
        }
    }
}
```

**Correct (sanitized with FilenameUtils):**
```java
public class FileServlet extends HttpServlet {
    public void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        String image = request.getParameter("image");
        File file = new File("static/images/", FilenameUtils.getName(image));
        if (!file.exists()) {
            response.sendError(404);
        }
    }
}
```

**References:**
- CWE-22: Path Traversal
- [OWASP Path Traversal](https://www.owasp.org/index.php/Path_Traversal)

---

### Language: Go

#### filepath.Clean Misuse

**Incorrect (Clean does not prevent traversal):**
```go
func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/file", func(w http.ResponseWriter, r *http.Request) {
        filename := filepath.Clean(r.URL.Path)
        filename = filepath.Join(root, strings.Trim(filename, "/"))
        contents, err := ioutil.ReadFile(filename)
        if err != nil {
            w.WriteHeader(http.StatusNotFound)
            return
        }
        w.Write(contents)
    })
}
```

**Correct (prefix with "/" before Clean):**
```go
func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/file", func(w http.ResponseWriter, r *http.Request) {
        filename := path.Clean("/" + r.URL.Path)
        filename = filepath.Join(root, strings.Trim(filename, "/"))
        contents, err := ioutil.ReadFile(filename)
        if err != nil {
            w.WriteHeader(http.StatusNotFound)
            return
        }
        w.Write(contents)
    })
}
```

**Best Practice:** Use `filepath.FromSlash(path.Clean("/"+strings.Trim(req.URL.Path, "/")))` or the `SecureJoin` function from `github.com/cyphar/filepath-securejoin`.

**References:**
- CWE-22: Path Traversal
- [Go path.Clean Documentation](https://pkg.go.dev/path#Clean)
- [filepath-securejoin Package](https://pkg.go.dev/github.com/cyphar/filepath-securejoin)

---

### Language: PHP

#### File Inclusion (LFI/RFI)

**Incorrect (vulnerable to path traversal/RFI):**
```php
<?php
$user_input = $_GET["page"];
include($user_input);
?>
```

**Correct (constant paths):**
```php
<?php
include('templates/header.php');
require_once(CONFIG_DIR . '/settings.php');
?>
```

**References:**
- CWE-98: PHP Remote File Inclusion
- [PHP include Documentation](https://www.php.net/manual/en/function.include.php)

---

#### unlink() Path Traversal

**Incorrect (vulnerable to path traversal):**
```php
<?php
$data = $_GET["file"];
unlink("/storage/" . $data);
?>
```

**Correct (constant path):**
```php
<?php
unlink('/storage/cache/temp.txt');
?>
```

**References:**
- CWE-22: Path Traversal
- [PHP unlink Documentation](https://www.php.net/manual/en/function.unlink)
