## Infrastructure Security Audit

Run a full-project infrastructure security audit. No arguments.

Read infrastructure code, run available local checks, and write only
`INFRA-SEC-AUDIT.md` in the project root. Do not change infrastructure,
secrets, workflows, or runtime state.

### Flow

1. **Fan-out**
   - Delegate to a wide fan-out of sub-agents, in parallel where possible.
     Split by directory, concern, tool, platform, or attack surface so each
     sub-agent has a small audit surface. Recurse into nested directories when
     useful. First-party infrastructure only; exclude git submodules. Each
     sub-agent runs this audit over its own area; the parent aggregates findings.
2. **Scope and threat model**
   - Confirm repositories, cloud accounts, clusters, CI/CD systems, networks, and live access in scope.
   - Inventory Terraform/HCL, Kubernetes, Docker/Compose, GitHub Actions, Nix, Helm, secrets, DNS, TLS, storage, and logging config found.
   - Map trust boundaries: internet to edge, edge to service, service to data store, CI/CD to cloud, build to deploy.
   - Default threat model: motivated external attacker with no access. Ask if insider, supply-chain, or compromised-runner risk is in scope.
   - Record limits, such as no cloud credentials, no live cluster access, or manifests only.

3. **Automated checks**
   Run checks that exist locally. Skip missing tools and list the gap in the report.

   | Area                | Checks                                                                                                                                                                                                            |
   | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | Terraform and cloud | `trivy config .`; public storage, open firewall rules, public IPs, weak TLS, missing encryption, missing backups, missing audit logs, wildcard IAM, broad `AssumeRole` or `PassRole`, static cloud keys.          |
   | Kubernetes          | `kubescape`, `kube-linter`; privileged pods, root containers, privilege escalation, host namespaces, Docker socket mounts, weak RBAC, missing NetworkPolicies, weak Secrets handling, missing admission controls. |
   | Docker              | `hadolint`, `dockle`; root users, `latest` or unpinned images, privileged mode, Docker socket exposure, broad capabilities, secrets in layers.                                                                    |
   | GitHub Actions      | `actionlint`, `semgrep`; shell injection from untrusted context, unsafe `pull_request_target` or `workflow_run`, unpinned actions, broad `permissions`, exposed secrets, long-lived cloud keys instead of OIDC.   |
   | Secrets             | `gitleaks`; plaintext secrets in worktree and history, tokens in config, keys in images, weak scoping, missing rotation.                                                                                          |
   | Supply chain        | `syft`, `grype`, `trivy image` where images are known; missing SBOM, vulnerable images, unsigned images, missing provenance, unpinned hashes or digests.                                                          |
   | Cloud posture       | `prowler` only when credentials exist; CIS cloud checks, public exposure, IAM, logging, encryption, key rotation.                                                                                                 |

4. **Manual checklist**
   - Cloud and Terraform: deny public access by default, restrict admin ports, enforce least privilege, encrypt storage and logs, enable backups, rotate KMS keys, avoid default networks, disable public database endpoints.
   - Kubernetes: block `cluster-admin` for workloads, scope RoleBindings, disable service-account token automount by default, require non-root and read-only filesystems, block host PID/IPC/network, encrypt etcd, use default-deny NetworkPolicies.
   - Docker and Compose: never run as root at rest, avoid `latest`, pin base images, avoid privileged mode, never mount `/var/run/docker.sock`, remove unused Linux capabilities.
   - GitHub Actions: use least `permissions`, pin third-party actions to full SHAs, route untrusted input through `env`, protect deploy environments, keep secrets out of fork and PR workflows, prefer OIDC to static keys.
   - Secrets: no plaintext secrets in Git, generated artefacts, logs, or image layers; use a secret manager or encrypted secrets; define rotation and certificate renewal.
   - Supply chain: pin dependencies by hash or digest, verify base image source, sign images, create SBOMs, attach provenance, enforce signature checks at deploy.
   - Blast radius: trace each viable path from entry point to data, admin rights, persistence, and cross-environment spread.

5. **Finding format and severity**
   Use Batfink's Shield Assessment format. For each Exposed or Weakened finding include:
   - **Title** - `file:line`
   - **Severity:** Exposed (Critical) or Weakened (Warning)
   - **Risk:** What an attacker gains.
   - **Attack path:** Initial access, pivot, privilege gain, data access, and persistence if relevant.
   - **Blast radius:** single resource, service, cluster, environment, or cross-environment.
   - **Evidence:** Exact config, scanner result, or missing control.
   - **Harden:** Specific config or tool change.
   - **Confidence:** Confirmed or needs live access.

### Report sections

- **Methodology:** scope, threat model, tools run, tools missing, limits.
- **Findings:** Exposed, Weakened, Reinforcement Opportunities.
- **Attack Path Summary:** highest-impact chain, one paragraph.
- **Repeat-Offender Patterns:** repeated weak defaults that need one architectural fix.
- **Remediation Roadmap:** ordered by blast radius first, then effort.

### Constraints

- Assess exploitability and blast radius before severity. Compliance can raise priority, but it does not replace an attack path.
- Do not report Exposed or Weakened without a viable attack path. Use Reinforcement Opportunities for hardening-only items.
- Reference the relevant CIS, NIST, NSA/CISA, SLSA, or vendor hardening guide for each Critical or Warning finding when known.
- Write the aggregated report to `INFRA-SEC-AUDIT.md` in the project root.
