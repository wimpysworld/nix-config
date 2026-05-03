---
title: Prevent Server-Side Request Forgery
impact: HIGH
impactDescription: Attackers can make requests from the server to internal systems, cloud metadata endpoints, or external services
tags: security, ssrf, cwe-918
---

## Prevent Server-Side Request Forgery (SSRF)

Server-Side Request Forgery (SSRF) occurs when an attacker can make a server-side application send HTTP requests to an arbitrary domain of the attacker's choosing. This can be used to:

- Access internal services and APIs that are not exposed to the internet
- Read cloud metadata endpoints (e.g., AWS EC2 metadata at 169.254.169.254)
- Scan internal networks and ports
- Bypass firewalls and access controls
- Exfiltrate sensitive data

---

### Language: Python

**Incorrect (user input flows into URL host):**
```python
from django.http import HttpResponse
import requests

def fetch_user_data(request):
    host = request.POST.get('host')
    user_id = request.POST.get('user_id')
    response = requests.get(f"https://{host}/api/users/{user_id}")
    return HttpResponse(response.content)
```

**Correct (fixed host, user data only in path):**
```python
from django.http import HttpResponse
import requests

def fetch_user_data(request):
    user_id = request.POST.get('user_id')
    response = requests.get(f"https://api.example.com/users/{user_id}")
    return HttpResponse(response.content)
```

---

### Language: JavaScript / Node.js

**Incorrect (user input in URL):**
```javascript
const express = require('express');
const axios = require('axios');
const app = express();

app.get('/fetch', async (req, res) => {
    const url = req.query.url;
    const response = await axios.get(url);
    res.send(response.data);
});
```

**Correct (fixed host, user data only in path):**
```javascript
const express = require('express');
const axios = require('axios');
const app = express();

app.get('/fetch', async (req, res) => {
    const resourceId = req.query.id;
    const response = await axios.get(`https://api.example.com/resources/${resourceId}`);
    res.send(response.data);
});
```

---

### Language: Java

**Incorrect (user-controlled URL):**
```java
import java.net.URL;
import java.net.URLConnection;
import org.springframework.web.bind.annotation.RequestParam;

@RestController
public class FetchController {
    @GetMapping("/fetch")
    public byte[] fetchImage(@RequestParam("url") String imageUrl) throws Exception {
        URL u = new URL(imageUrl);
        URLConnection conn = u.openConnection();
        return conn.getInputStream().readAllBytes();
    }
}
```

**Correct (fixed host, user data in path):**
```java
import java.net.URL;
import org.springframework.web.bind.annotation.RequestParam;

@RestController
public class FetchController {
    @GetMapping("/fetch")
    public byte[] fetchImage(@RequestParam("id") String imageId) throws Exception {
        String url = String.format("https://images.example.com/%s", imageId);
        URL u = new URL(url);
        return u.openConnection().getInputStream().readAllBytes();
    }
}
```

---

### Language: Go

**Incorrect (user input in URL host):**
```go
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    host := r.URL.Query().Get("host")
    url := fmt.Sprintf("https://%s/api/data", host)
    resp, _ := http.Get(url)
    defer resp.Body.Close()
}
```

**Correct (fixed host, user data in path):**
```go
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    resourceId := r.URL.Query().Get("id")
    url := fmt.Sprintf("https://api.example.com/data/%s", resourceId)
    resp, _ := http.Get(url)
    defer resp.Body.Close()
}
```

---

### Language: PHP

**Incorrect (user input in URL):**
```php
<?php
function fetchData() {
    $url = $_GET['url'];
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $response = curl_exec($ch);
    curl_close($ch);
    return $response;
}
?>
```

**Correct (fixed host, user data in path):**
```php
<?php
function fetchData() {
    $resourceId = $_GET['id'];
    $url = 'https://api.example.com/resources/' . $resourceId;
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $response = curl_exec($ch);
    curl_close($ch);
    return $response;
}
?>
```

---

### Language: Ruby

**Incorrect (user input in HTTP request):**
```ruby
require 'net/http'

def fetch_data
  url = params[:url]
  uri = URI(url)
  Net::HTTP.get_response(uri)
end
```

**Correct (fixed host, user data in path):**
```ruby
require 'net/http'

def fetch_data
  resource_id = params[:id]
  uri = URI("https://api.example.com/resources/#{resource_id}")
  Net::HTTP.get_response(uri)
end
```

---

**References:**
- CWE-918: Server-Side Request Forgery (SSRF)
- [OWASP Top 10 A10:2021 - Server-Side Request Forgery](https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29)
- [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
