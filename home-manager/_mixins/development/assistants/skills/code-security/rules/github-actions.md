---
title: Secure GitHub Actions
impact: HIGH
impactDescription: Prevents code injection, secrets theft, and supply chain attacks in CI/CD pipelines
tags: security, github-actions, ci-cd, cwe-78, cwe-94, cwe-913
---

## Secure GitHub Actions

GitHub Actions workflows can be vulnerable to several security issues including script injection, secrets exposure, and supply chain attacks. Attackers who exploit these vulnerabilities can steal repository secrets, inject malicious code, or compromise the entire CI/CD pipeline.

### Key Security Risks

1. **Script Injection**: Using untrusted input (like PR titles or issue bodies) directly in `run:` commands allows attackers to inject arbitrary code
2. **Privileged Triggers**: `pull_request_target` and `workflow_run` events run with elevated privileges, making checkout of untrusted code dangerous
3. **Supply Chain**: Third-party actions not pinned to commit SHAs can be compromised

---

### Run Shell Injection (CWE-78)

Using variable interpolation `${{...}}` with `github` context data in a `run:` step could allow an attacker to inject their own code into the runner. This would allow them to steal secrets and code.

**Incorrect (vulnerable to script injection via PR title):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check PR title
        run: |
          title="${{ github.event.pull_request.title }}"
          echo "$title"
```

**Correct (use environment variable):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check PR title
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          echo "$PR_TITLE"
```

**Fix**: Use an intermediate environment variable with `env:` to store the data and use the environment variable in the `run:` script. Be sure to use double-quotes around the environment variable.

**References:** [GitHub Actions Security Hardening - Script Injections](https://docs.github.com/en/actions/learn-github-actions/security-hardening-for-github-actions#understanding-the-risk-of-script-injections)

---

### Pull Request Target Code Checkout (CWE-913)

When using `pull_request_target`, the Action runs in the context of the target repository with access to all repository secrets. Checking out the incoming PR code while having access to secrets is dangerous because you may inadvertently execute arbitrary code from the incoming PR.

**Incorrect (checking out PR code with pull_request_target):**
```yaml
on:
  pull_request_target:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm install && npm build
```

**Correct (no checkout of PR code):**
```yaml
on:
  pull_request_target:

jobs:
  safe-job:
    runs-on: ubuntu-latest
    steps:
      - name: echo
        run: echo "Hello, world"
```

**References:** [GitHub Actions Preventing Pwn Requests](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)

---

### Workflow Run Target Code Checkout (CWE-913)

Similar to `pull_request_target`, when using `workflow_run`, the Action runs in the context of the target repository with access to all repository secrets. Checking out incoming PR code with this trigger is dangerous.

**Incorrect (checking out PR code with workflow_run):**
```yaml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: ${{ github.event.workflow_run.head.sha }}
      - run: npm install
```

**Correct (no checkout of PR code):**
```yaml
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

jobs:
  safe-job:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Safe operation"
```

**References:** [GitHub Privilege Escalation Vulnerability](https://www.legitsecurity.com/blog/github-privilege-escalation-vulnerability)

---

### Third-Party Action Not Pinned to Commit SHA (CWE-1357)

An action sourced from a third-party repository on GitHub is not pinned to a full length commit SHA. Pinning an action to a full length commit SHA is currently the only way to use an action as an immutable release.

**Incorrect (using tag reference):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: fakerepo/comment-on-pr@v1
        with:
          message: "Thank you!"
```

**Correct (pinned to full commit SHA):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: fakerepo/comment-on-pr@5fd3084fc36e372ff1fff382a39b10d03659f355
        with:
          message: "Thank you!"
```

Note: GitHub-owned actions (`actions/*`, `github/*`) and local actions (`./.github/actions/*`) don't require SHA pinning.

**References:** [GitHub Actions Security Hardening - Using Third-Party Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)

---

**References:**
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/learn-github-actions/security-hardening-for-github-actions)
- [GitHub Security Lab - Preventing Pwn Requests](https://securitylab.github.com/research/github-actions-preventing-pwn-requests/)
- [GitHub Security Lab - Untrusted Input](https://securitylab.github.com/research/github-actions-untrusted-input/)
