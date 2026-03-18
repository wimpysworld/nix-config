---
title: Prevent Code Injection
impact: CRITICAL
impactDescription: Remote code execution via eval/exec
tags: security, code-injection, rce, cwe-94, cwe-95, owasp-a03
---

## Prevent Code Injection

Code injection vulnerabilities occur when an attacker can insert and execute arbitrary code within your application. This includes direct code evaluation (eval, exec), reflection-based attacks, and dynamic method invocation. These vulnerabilities can lead to complete system compromise, data theft, and remote code execution.

**Incorrect (Python - eval with user input):**

```python
def unsafe(request):
    code = request.POST.get('code')
    eval(code)
```

**Correct (Python - static eval with hardcoded strings):**

```python
eval("x = 1; x = x + 2")

blah = "import requests; r = requests.get('https://example.com')"
eval(blah)
```

**Incorrect (JavaScript - eval with dynamic content):**

```javascript
let dynamic = window.prompt()

eval(dynamic + 'possibly malicious code');

function evalSomething(something) {
    eval(something);
}
```

**Correct (JavaScript - static eval strings):**

```javascript
eval('var x = "static strings are okay";');

const constVar = "function staticStrings() { return 'static strings are okay';}";
eval(constVar);
```

**Incorrect (Java - ScriptEngine injection):**

```java
public class ScriptEngineSample {

    private static ScriptEngineManager sem = new ScriptEngineManager();
    private static ScriptEngine se = sem.getEngineByExtension("js");

    public static void scripting(String userInput) throws ScriptException {
        Object result = se.eval("test=1;" + userInput);
    }
}
```

**Correct (Java - static ScriptEngine evaluation):**

```java
public class ScriptEngineSample {

    public static void scriptingSafe() throws ScriptException {
        ScriptEngineManager scriptEngineManager = new ScriptEngineManager();
        ScriptEngine scriptEngine = scriptEngineManager.getEngineByExtension("js");
        String code = "var test=3;test=test*2;";
        Object result = scriptEngine.eval(code);
    }
}
```

**Incorrect (Ruby - dangerous eval):**

```ruby
b = params['something']
eval(b)
eval(params['cmd'])
```

**Correct (Ruby - static eval):**

```ruby
eval("def zen; 42; end")

class Thing
end
a = %q{def hello() "Hello there!" end}
Thing.module_eval(a)
```

**Incorrect (PHP - dangerous exec functions with user input):**

```php
exec($user_input);
passthru($user_input);
$output = shell_exec($user_input);
$output = system($user_input, $retval);

$username = $_COOKIE['username'];
exec("wto -n \"$username\" -g", $ret);
```

**Correct (PHP - static commands with escapeshellarg):**

```php
exec('whoami');

$fullpath = $_POST['fullpath'];
$filesize = trim(shell_exec('stat -c %s ' . escapeshellarg($fullpath)));
```

## Key Prevention Patterns

1. **Never pass user input to eval/exec functions** - Treat all user input as untrusted
2. **Use hardcoded strings** - Static strings in eval/exec calls are safe
3. **Validate and sanitize** - If dynamic code execution is unavoidable, validate against a strict whitelist
4. **Use parameterized alternatives** - Many languages offer safer alternatives to eval
5. **Escape shell arguments** - Use escapeshellarg() in PHP or equivalent functions

## References

- [OWASP Code Injection](https://owasp.org/www-community/attacks/Code_Injection)
- [OWASP Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html)
- [CWE-94: Improper Control of Generation of Code](https://cwe.mitre.org/data/definitions/94.html)
- [CWE-95: Eval Injection](https://cwe.mitre.org/data/definitions/95.html)
- [MDN: Never use eval()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/eval#never_use_eval!)
