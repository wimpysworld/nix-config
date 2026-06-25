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
   - Inventory first-party Terraform/HCL, Kubernetes, Docker/Compose, GitHub Actions, Nix, Helm, secrets, DNS, TLS, storage, logging, IAM, network, and supply-chain config.
   - Map trust boundaries: internet to edge, edge to service, service to data store, CI/CD to cloud, build to deploy.
   - Default threat model: motivated external attacker with no access. Ask if insider, supply-chain, or compromised-runner risk is in scope.
   - Record limits, such as no cloud credentials, no live cluster access, or manifests only.

3. **Automated checks**
   Run checks that exist locally. Skip missing tools and list the gap. Record command, scope, and result.

   | Area                | Checks                                                                                                                                                                                                                                                                                                                                                           |
   | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | Terraform and cloud | `trivy config .`; AWS/Azure/GCP public storage or services, open firewall rules, public IPs/databases, default networks, weak TLS/HTTP, CORS `*`, disabled auth/debug controls, missing encryption/backups/audit or flow logs, weak KMS rotation, wildcard IAM/custom roles, broad `AssumeRole` or `PassRole`, service-account token minting, static cloud keys. |
   | Kubernetes          | `kubescape`, `kube-linter`; privileged pods, root containers, privilege escalation, host namespaces, Docker socket mounts, weak RBAC, plaintext or base64 Secrets, missing NetworkPolicies, weak admission controls.                                                                                                                                             |
   | Docker              | `hadolint`, `dockle`; root users, `latest` or unpinned images, privileged mode, Docker socket exposure, broad capabilities, writable root filesystems, missing `no-new-privileges`, secrets in layers.                                                                                                                                                           |
   | GitHub Actions      | `actionlint`, `semgrep`; untrusted `${{ }}` in `run`, unsafe `pull_request_target` or `workflow_run`, unpinned actions, broad `permissions` or `GITHUB_TOKEN`, exposed secrets, static cloud keys, weak OIDC subject or audience.                                                                                                                                |
   | Secrets             | `gitleaks`; plaintext secrets in worktree, history, Terraform state/vars, Kubernetes Secrets, CI logs, images, or generated files; weak scope or rotation.                                                                                                                                                                                                       |
   | Supply chain        | `syft`, `grype`, `trivy image` where images are known; missing SBOM, vulnerable or unsigned images, missing provenance, unpinned hashes or digests.                                                                                                                                                                                                              |
   | Cloud posture       | `prowler` only when credentials exist; CIS cloud checks, public exposure, IAM escalation paths, logging, encryption, key rotation.                                                                                                                                                                                                                               |

4. **Manual checklist**
   - Cloud and Terraform: deny public access by default, restrict admin ports, use private endpoints, remove default networks, require TLS 1.2+ and HTTPS, block public database, bucket, serverless, notebook, and control-plane access, use least-privilege IAM and OIDC trust conditions, encrypt storage, queues, topics, logs, backups, and Terraform state, enable audit, flow, and data-access logs, enable deletion protection, soft delete, and backups.
   - Kubernetes: block `cluster-admin` for workloads, scope RoleBindings, disable service-account token automount by default, require non-root, read-only filesystems, and `allowPrivilegeEscalation: false`, block host PID/IPC/network, encrypt etcd, use default-deny NetworkPolicies, avoid plaintext Secret manifests, enforce Pod Security or admission controls.
   - Docker and Compose: avoid root, `latest`, privileged mode, Docker socket mounts, broad capabilities, writable root filesystems, and missing `no-new-privileges`; pin images by digest when practical.
   - GitHub Actions: use least `permissions`, pin third-party actions to full SHAs, route untrusted input through `env`, protect deploy environments, isolate self-hosted runners, keep secrets out of fork and PR workflows, prefer OIDC to static keys, restrict OIDC claims.
   - Secrets: no plaintext secrets in Git, Terraform state, generated artefacts, logs, or image layers; use a secret manager or encrypted secrets; define rotation and certificate renewal.
   - Supply chain: pin dependencies by hash or digest, verify base image source, sign images, create SBOMs, attach provenance, enforce signature checks at deploy.
   - Blast radius: trace each viable path from entry point to data, admin rights, persistence, and cross-environment spread.

5. **Finding format and severity**
   Use Batfink's Shield Assessment format. For each Exposed or Weakened finding include:
   - **Title** - `file:line`
   - **Severity:** Exposed (Critical) or Weakened (Warning)
   - **Risk:** What an attacker gains.
   - **Attack path:** Initial access, pivot, privilege gain, data access, and persistence if relevant.
   - **Blast radius:** single resource, service, cluster, environment, or cross-environment.
   - **Scanner:** Tool name and finding ID when present.
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
- Mark Exposed only for a viable path to public data exposure, secret theft, admin or IAM escalation, container or cluster escape, CI/CD compromise, or cross-environment pivot. Mark Weakened for a credible path that needs another weakness. Use Reinforcement Opportunities for hardening-only items.
- Reference the relevant CIS, NIST, NSA/CISA, SLSA, or vendor hardening guide for each Critical or Warning finding when known.
- Write the aggregated report to `INFRA-SEC-AUDIT.md` in the project root.
