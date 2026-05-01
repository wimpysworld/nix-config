---
title: Prevent Cross-Site Request Forgery
impact: HIGH
impactDescription: Attackers can force authenticated users to perform unwanted actions, potentially modifying data, transferring funds, or changing account settings
tags: security, csrf, cwe-352, owasp-a01
---

## Prevent Cross-Site Request Forgery

Cross-Site Request Forgery (CSRF) is an attack that forces authenticated users to execute unwanted actions on a web application. When a user is authenticated, their browser automatically includes session cookies with requests. Attackers can craft malicious pages that trigger requests to vulnerable applications, causing actions to be performed without the user's consent.

---

### Language: Python / Django

#### CSRF Exempt Decorator

**Incorrect (using @csrf_exempt decorator):**
```python
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def my_view(request):
    return HttpResponse('Hello world')
```

**Correct (remove csrf_exempt decorator):**
```python
from django.http import HttpResponse

def my_view(request):
    return HttpResponse('Hello world')
```

**References:**
- [OWASP Top 10 A01:2021 - Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control)

---

### Language: JavaScript / Express

#### Missing CSRF Middleware

**Incorrect (Express app without csurf middleware):**
```javascript
var express = require('express')
var bodyParser = require('body-parser')

var app = express()

app.post('/process', bodyParser.urlencoded({ extended: false }), function(req, res) {
    res.send('data is being processed')
})
```

**Correct (include csurf middleware):**
```javascript
var csrf = require('csurf')
var express = require('express')

var app = express()
app.use(csrf({ cookie: true }))
```

**References:**
- [csurf npm package](https://www.npmjs.com/package/csurf)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)

---

### Language: Java / Spring

#### CSRF Disabled

**Incorrect (explicitly disabling CSRF protection):**
```java
@Configuration
@EnableWebSecurity
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .csrf().disable()
            .authorizeRequests()
                .antMatchers("/", "/home").permitAll()
                .anyRequest().authenticated();
    }
}
```

**Correct (CSRF protection enabled by default):**
```java
@Configuration
@EnableWebSecurity
public class WebSecurityConfig extends WebSecurityConfigurerAdapter {
    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .authorizeRequests()
                .antMatchers("/", "/home").permitAll()
                .anyRequest().authenticated();
    }
}
```

**References:**
- [Find Security Bugs - Spring CSRF](https://find-sec-bugs.github.io/bugs.htm#SPRING_CSRF_UNRESTRICTED_REQUEST_MAPPING)

---

### Language: Ruby / Rails

#### Missing CSRF Protection

**Incorrect (controller without protect_from_forgery):**
```ruby
class DangerousController < ActionController::Base
  puts "do more stuff"
end
```

**Correct (controller with protect_from_forgery):**
```ruby
class SafeController < ActionController::Base
  protect_from_forgery with: :exception

  puts "do more stuff"
end
```

**References:**
- [Rails ActionController RequestForgeryProtection](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html)

---

**General References:**
- CWE-352: Cross-Site Request Forgery (CSRF)
- [OWASP Top 10 A01:2021 - Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
