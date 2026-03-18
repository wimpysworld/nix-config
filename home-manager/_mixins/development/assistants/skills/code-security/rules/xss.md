---
title: Prevent Cross-Site Scripting (XSS)
impact: CRITICAL
impactDescription: Client-side code execution, session hijacking, credential theft
tags: security, xss, cwe-79
---

## Prevent Cross-Site Scripting (XSS)

XSS occurs when untrusted data is included in web pages without proper validation or escaping. Attackers can execute scripts in victim's browser to steal cookies, session tokens, or other sensitive data.

---

### Language: JavaScript

#### Browser DOM Manipulation

**Incorrect (vulnerable to XSS):**
```javascript
function renderUserContent(userInput) {
  document.body.innerHTML = '<div>' + userInput + '</div>';
}
```

**Correct (use textContent or sanitization):**
```javascript
function renderUserContent(userInput) {
  const div = document.createElement('div');
  div.textContent = userInput;
  document.body.appendChild(div);
}
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)

---

### Language: Python

#### Flask Unsanitized Response

**Incorrect (user input in response):**
```python
from flask import make_response, request

def search():
    query = request.args.get("q")
    return make_response(f"Results for: {query}")
```

**Correct (escape output):**
```python
from flask import make_response, request
from markupsafe import escape

def search():
    query = request.args.get("q")
    return make_response(f"Results for: {escape(query)}")
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [Flask Security Guide](https://flask.palletsprojects.com/en/1.0.x/security/)

---

#### Django HttpResponse

**Incorrect (request data in HttpResponse):**
```python
from django.http import HttpResponse

def greet(request):
    name = request.GET.get("name", "")
    return HttpResponse(f"Hello, {name}!")
```

**Correct (use template or escape):**
```python
from django.http import HttpResponse
from django.utils.html import escape

def greet(request):
    name = request.GET.get("name", "")
    return HttpResponse(f"Hello, {escape(name)}!")
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [Django Security](https://django-book.readthedocs.io/en/latest/chapter20.html#cross-site-scripting-xss)

---

### Language: Java

#### ServletResponse Writer XSS

**Incorrect (writing request parameters directly):**
```java
public class UserServlet extends HttpServlet {
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String name = req.getParameter("name");
        resp.getWriter().write("<h1>Hello " + name + "</h1>");
    }
}
```

**Correct (encode output):**
```java
import org.owasp.encoder.Encode;

public class UserServlet extends HttpServlet {
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String name = req.getParameter("name");
        resp.getWriter().write("<h1>Hello " + Encode.forHtml(name) + "</h1>");
    }
}
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [Find Security Bugs - XSS Servlet](https://find-sec-bugs.github.io/bugs.htm#XSS_SERVLET)

---

### Language: Go

#### Direct ResponseWriter Write

**Incorrect (writing user input to ResponseWriter):**
```go
func greetHandler(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Query().Get("name")
    template := "<html><body><h1>Hello %s</h1></body></html>"
    w.Write([]byte(fmt.Sprintf(template, name)))
}
```

**Correct (use html/template):**
```go
func greetHandler(w http.ResponseWriter, r *http.Request) {
    name := r.URL.Query().Get("name")
    tmpl := template.Must(template.New("greet").Parse(
        "<html><body><h1>Hello {{.}}</h1></body></html>"))
    tmpl.Execute(w, name)
}
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [Go Security - XSS](https://blogtitle.github.io/robn-go-security-pearls-cross-site-scripting-xss/)

---

### Language: PHP

#### Echo with Request Data

**Incorrect (echoing user input):**
```php
<?php
function greet() {
    $name = $_REQUEST['name'];
    echo "Hello: " . $name;
}
```

**Correct (use htmlspecialchars):**
```php
<?php
function greet() {
    $name = $_REQUEST['name'];
    echo "Hello: " . htmlspecialchars($name, ENT_QUOTES, 'UTF-8');
}
```

**References:**
- CWE-79: Improper Neutralization of Input During Web Page Generation
- [PHP htmlspecialchars()](https://www.php.net/manual/en/function.htmlspecialchars.php)

---

## General Prevention Guidelines

1. **Always escape output** - Use context-appropriate encoding (HTML, JavaScript, URL, CSS)
2. **Use framework-provided templating** - Most frameworks auto-escape by default
3. **Validate and sanitize input** - Whitelist allowed characters/patterns
4. **Use Content Security Policy (CSP)** - Add defense-in-depth via HTTP headers
5. **Use sanitization libraries** - DOMPurify, sanitize-html, OWASP Java Encoder
6. **Never trust user input** - Treat all external data as potentially malicious
7. **Set HttpOnly flag on cookies** - Prevents JavaScript access to session cookies
