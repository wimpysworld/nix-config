---
title: Avoid Unsafe Functions
impact: HIGH
impactDescription: Buffer overflows and memory corruption
tags: security, unsafe-functions, c, php, python, go, rust, cwe-120, cwe-676
---

## Avoid Unsafe Functions

Certain functions in various programming languages are inherently dangerous because they do not perform boundary checks, can lead to buffer overflows, have been deprecated, or bypass type safety mechanisms. Using these functions can result in security vulnerabilities, memory corruption, and arbitrary code execution.

**Incorrect (C - strcat buffer overflow):**

```c
int bad_strcpy(src, dst) {
    n = DST_BUFFER_SIZE;
    if ((dst != NULL) && (src != NULL) && (strlen(dst)+strlen(src)+1 <= n))
    {
        // ruleid: insecure-use-strcat-fn
        strcat(dst, src);

        // ruleid: insecure-use-strcat-fn
        strncat(dst, src, 100);
    }
}
```

**Correct (C - use strcat_s with bounds checking):**

```c
// Use strcat_s which performs bounds checking
```

**Incorrect (C - strcpy buffer overflow):**

```c
int bad_strcpy(src, dst) {
    n = DST_BUFFER_SIZE;
    if ((dst != NULL) && (src != NULL) && (strlen(dst)+strlen(src)+1 <= n))
    {
        // ruleid: insecure-use-string-copy-fn
        strcpy(dst, src);

        // ruleid: insecure-use-string-copy-fn
        strncpy(dst, src, 100);
    }
}
```

**Correct (C - use strcpy_s with bounds checking):**

```c
// Use strcpy_s which performs bounds checking
```

**Incorrect (C - strtok modifies buffer):**

```c
int bad_code() {
    char str[DST_BUFFER_SIZE];
    fgets(str, DST_BUFFER_SIZE, stdin);
    // ruleid:insecure-use-strtok-fn
    strtok(str, " ");
    printf("%s", str);
    return 0;
}
```

**Correct (C - use strtok_r instead):**

```c
int main() {
    char str[DST_BUFFER_SIZE];
    char dest[DST_BUFFER_SIZE];
    fgets(str, DST_BUFFER_SIZE, stdin);
    // ok:insecure-use-strtok-fn
    strtok_r(str, " ", *dest);
    printf("%s", str);
    return 0;
}
```

**Incorrect (C - scanf buffer overflow):**

```c
int bad_code() {
    char str[DST_BUFFER_SIZE];
    // ruleid:insecure-use-scanf-fn
    scanf("%s", str);
    printf("%s", str);
    return 0;
}
```

**Correct (C - use fgets instead):**

```c
int main() {
    char str[DST_BUFFER_SIZE];
    // ok:insecure-use-scanf-fn
    fgets(str);
    printf("%s", str);
    return 0;
}
```

**Incorrect (C - gets buffer overflow):**

```c
int bad_code() {
    char str[DST_BUFFER_SIZE];
    // ruleid:insecure-use-gets-fn
    gets(str);
    printf("%s", str);
    return 0;
}
```

**Correct (C - use fgets or gets_s instead):**

```c
int main() {
    char str[DST_BUFFER_SIZE];
    // ok:insecure-use-gets-fn
    fgets(str);
    printf("%s", str);
    return 0;
}
```

**Incorrect (PHP - deprecated mcrypt functions):**

```php
<?php

// ruleid: mcrypt-use
mcrypt_ecb(MCRYPT_BLOWFISH, $key, base64_decode($input), MCRYPT_DECRYPT);

// ruleid: mcrypt-use
mcrypt_create_iv($iv_size, MCRYPT_RAND);

// ruleid: mcrypt-use
mdecrypt_generic($td, $c_t);
```

**Correct (PHP - use Sodium or OpenSSL):**

```php
<?php

// ok: mcrypt-use
sodium_crypto_secretbox("Hello World!", $nonce, $key);

// ok: mcrypt-use
openssl_encrypt($plaintext, $cipher, $key, $options=0, $iv, $tag);
```

**Incorrect (Python - tempfile.mktemp race condition):**

```python
import tempfile as tf

# ruleid: tempfile-insecure
x = tempfile.mktemp()
# ruleid: tempfile-insecure
x = tempfile.mktemp(dir="/tmp")
```

**Correct (Python - use NamedTemporaryFile):**

```python
import tempfile

# Use NamedTemporaryFile instead
with tempfile.NamedTemporaryFile() as tmp:
    tmp.write(b"data")
```

**Incorrect (Go - unsafe package bypasses type safety):**

```go
package main

import (
	"fmt"
	"unsafe"

	foobarbaz "unsafe"
)

type Fake struct{}

func (Fake) Good() {}
func main() {
	unsafeM := Fake{}
	unsafeM.Good()
	intArray := [...]int{1, 2}
	fmt.Printf("\nintArray: %v\n", intArray)
	intPtr := &intArray[0]
	fmt.Printf("\nintPtr=%p, *intPtr=%d.\n", intPtr, *intPtr)
	// ruleid: use-of-unsafe-block
	addressHolder := uintptr(foobarbaz.Pointer(intPtr)) + unsafe.Sizeof(intArray[0])
	// ruleid: use-of-unsafe-block
	intPtr = (*int)(foobarbaz.Pointer(addressHolder))
	fmt.Printf("\nintPtr=%p, *intPtr=%d.\n\n", intPtr, *intPtr)
}
```

**Correct (Go - avoid unsafe package):**

```go
// Avoid using the unsafe package. Use Go's type-safe alternatives for memory operations.
```

**Incorrect (Rust - unsafe block bypasses safety):**

```rust
// ruleid: unsafe-usage
let pid = unsafe { libc::getpid() as u32 };
```

**Correct (Rust - use safe alternatives):**

```rust
// ok: unsafe-usage
let pid = libc::getpid() as u32;
```

**Incorrect (OCaml - unsafe functions skip bounds checks):**

```ocaml
let cb = Array.make 10 2 in
(* ruleid:ocamllint-unsafe *)
Printf.printf "%d\n" (Array.unsafe_get cb 12)
```

**Correct (OCaml - use bounds-checked functions):**

```ocaml
let cb = Array.make 10 2 in
(* Use bounds-checked version *)
Printf.printf "%d\n" (Array.get cb 0)
```
