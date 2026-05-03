---
title: Prevent Command Injection
impact: CRITICAL
impactDescription: Remote code execution allowing attackers to run arbitrary commands on the host system
tags: security, command-injection, cwe-78, cwe-94
---

## Prevent Command Injection

Command injection occurs when untrusted input is passed to system shell commands. Attackers can execute arbitrary commands on the host system, potentially downloading malware, stealing data, or taking complete control of the server.

---

### Language: Python

**Incorrect (vulnerable to command injection via subprocess):**
```python
import subprocess
import flask

app = flask.Flask(__name__)

@app.route("/ping")
def ping():
    ip = flask.request.args.get("ip")
    subprocess.run("ping " + ip, shell=True)
```

**Correct (use array form without shell=True):**
```python
import subprocess
import flask

app = flask.Flask(__name__)

@app.route("/ping")
def ping():
    ip = flask.request.args.get("ip")
    subprocess.run(["ping", ip])
```

---

### Language: JavaScript / Node.js

**Incorrect (vulnerable child_process with user input):**
```javascript
const { exec } = require('child_process');

function runCommand(userInput) {
    exec(`cat ${userInput}`, (error, stdout, stderr) => {
        console.log(stdout);
    });
}
```

**Correct (use spawn with array arguments):**
```javascript
const { spawn } = require('child_process');

function runCommand(userInput) {
    const proc = spawn('cat', [userInput]);
    proc.stdout.on('data', (data) => {
        console.log(data.toString());
    });
}
```

---

### Language: Java

**Incorrect (ProcessBuilder with user input via shell):**
```java
public class CommandRunner {

    public void runCommand(String userInput) throws IOException {
        String[] cmd = {"/bin/bash", "-c", userInput};
        ProcessBuilder builder = new ProcessBuilder(cmd);
        Process proc = builder.start();
    }
}
```

**Correct (use ProcessBuilder with array arguments, no shell):**
```java
public class CommandRunner {

    public void runCommand(String filename) throws IOException {
        ProcessBuilder builder = new ProcessBuilder("cat", filename);
        Process proc = builder.start();
    }
}
```

---

### Language: Go

**Incorrect (dangerous command with user input via stdin):**
```go
import (
    "fmt"
    "os/exec"
)

func runCommand(userInput string) {
    cmd := exec.Command("bash")
    cmdWriter, _ := cmd.StdinPipe()
    cmd.Start()

    cmdString := fmt.Sprintf("echo %s", userInput)
    cmdWriter.Write([]byte(cmdString + "\n"))

    cmd.Wait()
}
```

**Correct (use exec.Command with explicit arguments):**
```go
import (
    "os/exec"
)

func runCommand(filename string) {
    cmd := exec.Command("cat", filename)
    output, _ := cmd.Output()
    println(string(output))
}
```

---

### Language: Ruby

**Incorrect (Shell methods with tainted input):**
```ruby
require 'shell'

def read_file(params)
    Shell.cat(params[:filename])
end
```

**Correct (use hardcoded or validated paths):**
```ruby
require 'shell'

def read_log
    Shell.cat("/var/log/www/access.log")
end
```

---

**References:**
- CWE-78: Improper Neutralization of Special Elements used in an OS Command ('OS Command Injection')
- CWE-94: Improper Control of Generation of Code ('Code Injection')
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [OWASP Top 10 A03:2021 - Injection](https://owasp.org/Top10/A03_2021-Injection)
