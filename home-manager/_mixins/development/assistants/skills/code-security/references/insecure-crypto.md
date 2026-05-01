---
title: Avoid Insecure Cryptography
impact: HIGH
impactDescription: Data decryption and signature forgery
tags: security, cryptography, hashing, encryption, cwe-327, cwe-328, owasp-a02
---

## Avoid Insecure Cryptography

Using weak or broken cryptographic algorithms puts sensitive data at risk. Attackers can exploit known vulnerabilities in deprecated algorithms to decrypt data, forge signatures, or predict "random" values.

**Key vulnerabilities:**
- **Weak hashing:** MD5 and SHA1 are vulnerable to collision attacks
- **Weak encryption:** DES is deprecated due to small key/block sizes

**References:** CWE-327 (Broken Crypto Algorithm), CWE-328 (Weak Hash), CWE-326 (Inadequate Encryption Strength)

---

### Python

**Incorrect (MD5/SHA1 hashing):**

```python
import hashlib

hash_val = hashlib.md5(data).hexdigest()
hash_val = hashlib.sha1(data).hexdigest()
```

**Correct (SHA256 hashing):**

```python
import hashlib

hash_val = hashlib.sha256(data).hexdigest()
```

**Incorrect (DES cipher):**

```python
from Crypto.Cipher import DES

key = b'-8B key-'
cipher = DES.new(key, DES.MODE_CTR, counter=ctr)
```

**Correct (AES cipher):**

```python
from Crypto.Cipher import AES

key = b'Sixteen byte key'
cipher = AES.new(key, AES.MODE_EAX, nonce=nonce)
```

---

### JavaScript

**Incorrect (MD5 hashing):**

```javascript
const crypto = require("crypto");

function hashPassword(pwtext) {
    return crypto.createHash("md5").update(pwtext).digest("hex");
}
```

**Correct (SHA256 hashing):**

```javascript
const crypto = require("crypto");

function hashPassword(pwtext) {
    return crypto.createHash("sha256").update(pwtext).digest("hex");
}
```

---

### Java

**Incorrect (MD5/SHA1 hashing):**

```java
import java.security.MessageDigest;

MessageDigest md5 = MessageDigest.getInstance("MD5");
md5.update(password.getBytes());
byte[] hash = md5.digest();

MessageDigest sha1 = MessageDigest.getInstance("SHA-1");
```

**Correct (SHA-512 hashing):**

```java
import java.security.MessageDigest;

MessageDigest sha512 = MessageDigest.getInstance("SHA-512");
sha512.update(password.getBytes());
byte[] hash = sha512.digest();
```

**Incorrect (DES cipher):**

```java
Cipher c = Cipher.getInstance("DES/ECB/PKCS5Padding");
c.init(Cipher.ENCRYPT_MODE, k, iv);
```

**Correct (AES with GCM):**

```java
Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
c.init(Cipher.ENCRYPT_MODE, k, iv);
```

---

### Go

**Incorrect (MD5 hashing):**

```go
import (
    "crypto/md5"
    "fmt"
)

func hashData(data []byte) {
    h := md5.New()
    h.Write(data)
    fmt.Printf("%x", h.Sum(nil))
}
```

**Correct (SHA256 hashing):**

```go
import (
    "crypto/sha256"
    "fmt"
)

func hashData(data []byte) {
    h := sha256.New()
    h.Write(data)
    fmt.Printf("%x", h.Sum(nil))
}
```

**Incorrect (DES cipher):**

```go
import "crypto/des"

func encrypt() {
    key := []byte("example key 1234")
    block, _ := des.NewCipher(key[:8])
}
```

**Correct (AES cipher):**

```go
import "crypto/aes"

func encrypt() {
    key := []byte("example key 12345678901234567890")
    block, _ := aes.NewCipher(key[:32])
}
```

---

### Remediation Summary

| Language   | Weak Algorithm | Secure Alternative |
|------------|----------------|-------------------|
| Python     | `hashlib.md5`, `hashlib.sha1` | `hashlib.sha256`, `hashlib.sha512` |
| Python     | `DES.new()` | `AES.new()` with EAX/GCM mode |
| JavaScript | `createHash("md5")` | `createHash("sha256")` |
| Java       | `getInstance("MD5")`, `getInstance("SHA-1")` | `getInstance("SHA-512")` |
| Java       | `getInstance("DES")` | `getInstance("AES/GCM/NoPadding")` |
| Go         | `crypto/md5`, `crypto/sha1` | `crypto/sha256`, `crypto/sha512` |
| Go         | `crypto/des` | `crypto/aes` |

### Best Practices

1. **Hashing:** Use SHA-256 or SHA-512 for general hashing. For passwords, use bcrypt, scrypt, or Argon2.
2. **Encryption:** Use AES with authenticated modes (GCM, EAX). Avoid ECB mode.
3. **Key sizes:** RSA keys should be at least 2048 bits. AES keys should be 256 bits.
4. **Random numbers:** Use cryptographically secure random number generators for security-sensitive operations.
