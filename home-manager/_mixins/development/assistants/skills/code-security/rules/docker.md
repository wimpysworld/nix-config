---
title: Secure Docker Configurations
impact: HIGH
impactDescription: Container escapes and privilege escalation
tags: security, docker, containers, infrastructure, cwe-250
---

## Secure Docker Configurations

This guide provides security best practices for Dockerfiles and docker-compose configurations. Following these patterns helps prevent container escapes, privilege escalation, and other security vulnerabilities in containerized environments.

### Running as Root

The last user in the container should not be 'root'. If an attacker gains control of the container, they will have root access.

**Incorrect:**

```dockerfile
FROM busybox
RUN apt-get update && apt-get install -y some-package
USER appuser
USER root
```

**Correct:**

```dockerfile
FROM busybox
USER root
RUN apt-get update && apt-get install -y some-package
USER appuser
```

### Missing Image Version

Images should be tagged with an explicit version to produce deterministic container builds.

**Incorrect:**

```dockerfile
FROM debian
```

**Correct:**

```dockerfile
FROM debian:bookworm
```

### Using Latest Tag

The 'latest' tag may change the base container without warning, producing non-deterministic builds.

**Incorrect:**

```dockerfile
FROM debian:latest
```

**Correct:**

```dockerfile
FROM debian:bookworm
```

### Privileged Mode (Docker Compose)

Running containers in privileged mode grants the container the equivalent of root capabilities on the host machine. This can lead to container escapes, privilege escalation, and other security concerns.

**Incorrect:**

```yaml
version: "3.9"
services:
  worker:
    image: my-worker-image:1.0
    privileged: true
```

**Correct:**

```yaml
version: "3.9"
services:
  worker:
    image: my-worker-image:1.0
    privileged: false
```

### Exposing Docker Socket

Exposing the host's Docker socket to containers via a volume is equivalent to giving unrestricted root access to your host. Never expose the Docker socket unless absolutely necessary.

**Incorrect:**

```yaml
version: "3.9"
services:
  worker:
    image: my-worker-image:1.0
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

**Correct:**

```yaml
version: "3.9"
services:
  worker:
    image: my-worker-image:1.0
    volumes:
      - /tmp/data:/tmp/data
```

### Arbitrary Container Run (Python Docker SDK)

If unverified user data can reach the `run` or `create` method, it can result in running arbitrary containers.

**Incorrect:**

```python
import docker
client = docker.from_env()

def run_container(user_input):
    client.containers.run(user_input, 'echo hello world')
```

**Correct:**

```python
import docker
client = docker.from_env()

def run_container():
    client.containers.run("alpine", 'echo hello world')
```
