---
title: Use Secure Transport
impact: HIGH
impactDescription: Exposure of sensitive data through cleartext transmission or improper certificate validation
tags: security, insecure-transport, tls, ssl, cwe-295, cwe-319, cwe-311
---

## Use Secure Transport

Insecure transport vulnerabilities occur when applications transmit sensitive data over unencrypted connections or when TLS/SSL certificate validation is disabled. This exposes data to man-in-the-middle (MITM) attacks where attackers can intercept, read, and modify communications. Key issues include:

- **Cleartext transmission**: Using HTTP instead of HTTPS
- **Disabled certificate verification**: Accepting any SSL certificate without validation

---

### Language: JavaScript/Node.js

**Incorrect (HTTP requests without TLS):**
```javascript
const http = require('http');

http.get('http://nodejs.org/dist/index.json', (res) => {
    const { statusCode } = res;
});
```

**Correct (HTTPS requests with TLS):**
```javascript
const https = require('https');

https.get('https://nodejs.org/dist/index.json', (res) => {
    const { statusCode } = res;
});
```

**Incorrect (disabled TLS verification):**
```javascript
process.env["NODE_TLS_REJECT_UNAUTHORIZED"] = 0;

var req = https.request({
    host: '192.168.1.1',
    port: 443,
    path: '/',
    method: 'GET',
    rejectUnauthorized: false
});
```

**Correct (TLS verification enabled):**
```javascript
var req = https.request({
    host: '192.168.1.1',
    port: 443,
    path: '/',
    method: 'GET',
    rejectUnauthorized: true
});
```

**References:** [Node.js HTTPS Documentation](https://nodejs.org/api/https.html)

---

### Language: Go

**Incorrect (HTTP requests without TLS):**
```go
func bad() {
    resp, err := http.Get("http://example.com/")
}
```

**Correct (HTTPS requests):**
```go
func ok() {
    resp, err := http.Get("https://example.com/")
}
```

**Incorrect (disabled TLS verification):**
```go
import (
    "crypto/tls"
    "net/http"
)

func bad() {
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                InsecureSkipVerify: true,
            },
        },
    }
}
```

**Correct (TLS verification enabled):**
```go
func ok() {
    client := &http.Client{
        Transport: &http.Transport{
            TLSClientConfig: &tls.Config{
                InsecureSkipVerify: false,
            },
        },
    }
}
```

**References:** [Go TLS Documentation](https://golang.org/pkg/crypto/tls/)

---

### Language: Python

**Incorrect (HTTP requests without TLS):**
```python
import requests

requests.get("http://example.com")
```

**Correct (HTTPS requests):**
```python
import requests

requests.get("https://example.com")
```

**Incorrect (disabled certificate verification):**
```python
import requests

r = requests.get("https://example.com", verify=False)
```

**Correct (certificate verification enabled):**
```python
import requests

r = requests.get("https://example.com")
```

**References:** [Python SSL Documentation](https://docs.python.org/3/library/ssl.html)

---

### Language: Java

**Incorrect (HTTP requests without TLS):**
```java
HttpClient client = HttpClient.newHttpClient();
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("http://openjdk.java.net/"))
    .build();

client.sendAsync(request, BodyHandlers.ofString())
    .thenApply(HttpResponse::body)
    .thenAccept(System.out::println)
    .join();
```

**Correct (HTTPS requests):**
```java
HttpClient client = HttpClient.newHttpClient();
HttpRequest request = HttpRequest.newBuilder()
    .uri(URI.create("https://openjdk.java.net/"))
    .build();

client.sendAsync(request, BodyHandlers.ofString())
    .thenApply(HttpResponse::body)
    .thenAccept(System.out::println)
    .join();
```

**Incorrect (disabled TLS verification via empty X509TrustManager):**
```java
new X509TrustManager() {
    public X509Certificate[] getAcceptedIssuers() { return null; }
    public void checkClientTrusted(X509Certificate[] certs, String authType) { }
    public void checkServerTrusted(X509Certificate[] certs, String authType) { }
}
```

**Correct (proper certificate validation):**
```java
new X509TrustManager() {
    public X509Certificate[] getAcceptedIssuers() { return null; }
    public void checkClientTrusted(X509Certificate[] certs, String authType) { }
    public void checkServerTrusted(X509Certificate[] certs, String authType) {
        try {
            checkValidity();
        } catch (Exception e) {
            throw new CertificateException("Certificate not valid or trusted.");
        }
    }
}
```

**References:** [Java HTTPS Documentation](https://docs.oracle.com/en/java/javase/11/docs/api/java.net.http/java/net/http/HttpClient.html)

---

## Summary of CWEs

- **CWE-295**: Improper Certificate Validation
- **CWE-311**: Missing Encryption of Sensitive Data
- **CWE-319**: Cleartext Transmission of Sensitive Information

## References

- [OWASP Cryptographic Failures](https://owasp.org/Top10/A02_2021-Cryptographic_Failures)
- [OWASP Transport Layer Protection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)
- [CWE-319: Cleartext Transmission of Sensitive Information](https://cwe.mitre.org/data/definitions/319.html)
- [CWE-295: Improper Certificate Validation](https://cwe.mitre.org/data/definitions/295.html)
