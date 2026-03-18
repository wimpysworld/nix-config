---
title: Ensure Memory Safety
impact: CRITICAL
impactDescription: Arbitrary code execution and data corruption
tags: security, memory-safety, buffer-overflow, c, cpp, cwe-415, cwe-416, cwe-119
---

## Ensure Memory Safety

Memory safety vulnerabilities are among the most critical security issues in software development. They can lead to arbitrary code execution, data corruption, denial of service, and information disclosure. This guide covers common memory safety issues in C/C++ including double-free, use-after-free, and buffer overflow vulnerabilities.

### Double Free (CWE-415)

Freeing memory twice can cause memory corruption, crashes, or allow attackers to execute arbitrary code.

**Incorrect:**

```c
int bad_code() {
    char *var = malloc(sizeof(char) * 10);
    free(var);
    free(var);  // Double free vulnerability
    return 0;
}
```

**Correct:**

```c
int safe_code() {
    char *var = malloc(sizeof(char) * 10);
    free(var);
    var = NULL;  // Set to NULL after free
    free(var);   // Safe: freeing NULL is a no-op
    return 0;
}
```

### Use After Free (CWE-416)

Accessing memory after it has been freed can lead to crashes, data corruption, or code execution.

**Incorrect:**

```c
typedef struct name {
    char *myname;
    void (*func)(char *str);
} NAME;

int bad_code() {
    NAME *var;
    var = (NAME *)malloc(sizeof(struct name));
    free(var);
    var->func("use after free");  // Accessing freed memory
    return 0;
}
```

**Correct:**

```c
typedef struct name {
    char *myname;
    void (*func)(char *str);
} NAME;

int safe_code() {
    NAME *var;
    var = (NAME *)malloc(sizeof(struct name));
    free(var);
    var = NULL;  // Prevents accidental reuse
    // Any access to var now causes immediate crash (easier to debug)
    return 0;
}
```

### Buffer Overflow (CWE-119, CWE-120)

Writing beyond buffer boundaries can overwrite adjacent memory, leading to crashes or code execution.

**Incorrect:**

```c
void bad_code(char *user_input) {
    char buffer[64];
    strcpy(buffer, user_input);  // No bounds checking
}
```

**Correct:**

```c
void safe_code(char *user_input) {
    char buffer[64];
    strncpy(buffer, user_input, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';  // Ensure null termination
}
```

### Format String Vulnerabilities (CWE-134)

Using user-controlled format strings can allow attackers to read or write arbitrary memory.

**Incorrect:**

```c
void bad_printf(char *user_input) {
    printf(user_input);  // User controls format string
}
```

**Correct:**

```c
void safe_printf(char *user_input) {
    printf("%s", user_input);  // Format string is fixed
}
```

### Prevention Best Practices

1. **Set pointers to NULL after freeing** - Prevents use-after-free and double-free
2. **Use bounded string functions** - `strncpy`, `snprintf` instead of `strcpy`, `sprintf`
3. **Never use user input as format strings** - Always use fixed format strings
4. **Validate array indices** - Check bounds before accessing arrays
5. **Use static analysis tools** - Semgrep, Coverity, or similar to detect issues
6. **Consider memory-safe languages** - Rust, Go, or managed languages where appropriate
