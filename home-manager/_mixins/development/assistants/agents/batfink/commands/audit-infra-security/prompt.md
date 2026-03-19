## Infrastructure Security Audit

**Usage:** `/audit-infra-security <output-file>`

The first argument is the file path to write the completed audit report to (e.g. `infra-audit-2026-03-18.md`). Ask if not provided before proceeding.

Conduct a layered infrastructure security audit following a five-phase methodology. This command overrides Batfink's default sweep with a structured, outside-in approach ordered by blast radius and exploitability.

Reference frameworks: CIS Benchmarks, NIST SP 800-53 Rev. 5, NIST SP 800-190, NIST SP 800-207, NSA/CISA Kubernetes Hardening Guide v1.2, CSA Cloud Controls Matrix v4.1, SLSA.

### Phase 1: Scope and Inventory

Before assessing any configuration:

1. **Define boundaries** - Which repositories, clusters, cloud accounts, CI/CD systems, and network segments are in scope; ask if not specified
2. **Enumerate assets** - List infrastructure components visible in the codebase: cloud resources, container registries, Kubernetes clusters, CI/CD pipelines, secrets stores, DNS and TLS configurations
3. **Map trust boundaries** - Identify where trust transitions occur: public internet to load balancer, application to database, service-to-service, CI/CD to cloud
4. **Establish threat model** - Default: motivated external attacker with no initial access; ask if insider threat, supply chain attacker, or compromised pipeline applies
5. **Identify compliance scope** - Note any frameworks that apply (CIS, SOC 2, PCI-DSS, HIPAA); record them for Phase 4 where compliance requirements can elevate effective severity

### Phase 2: Automated Scanning

Read and assess all infrastructure-as-code files. Run automated checks in this order:

| Layer | Tool | Rulesets / Scope |
|-------|------|-----------------|
| Terraform / HCL | Trivy | `trivy config .` - all `.tf` and HCL files; flag Critical and High |
| Kubernetes YAML | Kubescape + kube-linter | CIS Kubernetes Benchmark, NSA/CISA profiles, and best-practice linting |
| Dockerfiles | Hadolint + Dockle | Dockerfile source linting (Hadolint) and built-image CIS compliance (Dockle) |
| GitHub Actions | Actionlint + Semgrep | Injection, pinning, permissions, OIDC |
| Secrets in code | Gitleaks | Working tree and full git history; flag history findings as confirmed even if removed |
| Container images | Trivy + Grype | CVEs against NVD/OSV; Trivy for broad scanning, Grype for SBOM-matched vulnerability analysis |
| Supply chain / SBOM | Syft + Grype | `syft scan` generates SBOM (CycloneDX/SPDX); `grype sbom:` matches the SBOM against vulnerability DBs |
| Cloud posture | Prowler | CIS cloud benchmark checks; requires cloud credentials - skip with explicit warning if absent |

Triage all results before proceeding. Document true positives as findings. Dismiss false positives with rationale.

### Phase 3: Manual Configuration Review

Manual review targets architectural weaknesses, logic errors, and business-context risks that automated tools miss. Assess each domain in order:

**3a. Identity and Access Management**

| Check | Reference |
|-------|-----------|
| Wildcard permissions (`Action: *`, `Resource: *`) in IAM policies | CIS cloud benchmarks |
| Privilege escalation paths: `iam:PassRole`, `sts:AssumeRole` chains, K8s impersonation | Cloud attack path analysis |
| Shared service accounts across workloads | NIST AC-2, CIS K8s 5.1.x |
| MFA enforced for all human users, especially admin accounts | CIS cloud benchmarks |
| Standing admin access vs just-in-time elevation | NIST AC-2(6), zero trust |
| K8s RBAC: no `cluster-admin` for workloads; scoped RoleBindings | CIS K8s 5.1.x |
| Automount of service account tokens disabled by default | CIS K8s 5.1.6 |

**3b. Network Architecture**

| Check | Reference |
|-------|-----------|
| Ingress rules allowing `0.0.0.0/0` except at load balancer tier | CIS cloud benchmarks |
| Missing Kubernetes NetworkPolicies (default-deny per namespace) | NSA/CISA, CIS K8s 5.3.x |
| Internal services exposed to public internet | NIST SP 800-207 tenet 5 |
| TLS version: 1.2 minimum, 1.3 preferred; no deprecated cipher suites | NIST SC family |
| mTLS between internal services | Zero trust, NIST SP 800-207 tenet 2 |
| DNS security: no open resolvers, DNSSEC where applicable | CIS benchmarks |

**3c. Container and Orchestration**

| Check | Reference |
|-------|-----------|
| Privileged containers or `allowPrivilegeEscalation: true` | CIS K8s 5.2.x, NSA/CISA |
| Containers running as root (`runAsNonRoot: false` or absent) | NIST SP 800-190, CIS Docker |
| Missing `readOnlyRootFilesystem: true` | CIS K8s 5.2.x |
| Host namespace sharing: `hostPID`, `hostIPC`, `hostNetwork` | NSA/CISA, CIS K8s |
| Missing CPU/memory resource limits | CIS K8s 5.2.x |
| Base images: use of `latest` tag or large general-purpose images | NIST SP 800-190 image risks |
| Image pull policy not `Always` for mutable tags | CIS K8s |
| etcd: encryption at rest, TLS client connections, restricted access | CIS K8s 2.x |
| Admission control: OPA Gatekeeper or Kyverno policies enforcing pod security | NSA/CISA |

**3d. CI/CD Pipeline**

| Check | Reference |
|-------|-----------|
| Workflow default permissions not `read-only` | GitHub Actions hardening guide |
| Third-party actions not pinned to full commit SHA | GitHub hardening guide, CWE-1357 |
| Secrets accessible from pull request workflows or fork builds | GitHub security docs |
| `pull_request_target` or `workflow_run` triggers handling untrusted input | GitHub security lab |
| Self-hosted runners shared across trust boundaries | GitHub runner security |
| No environment protection rules (required reviewers, deployment branches) on production | GitHub environments |
| No OIDC for cloud authentication (long-lived static credentials in use) | GitHub OIDC docs |
| No artifact attestations or SLSA provenance | SLSA Level 2+, GitHub docs |

**3e. Secrets Management**

| Check | Reference |
|-------|-----------|
| Secrets stored in Git plaintext (even if subsequently deleted) | Gitleaks, NIST IA-5 |
| Secrets baked into container image layers | NIST SP 800-190 |
| No rotation policy or long-lived static credentials | NIST IA-5, CSA CCM CEK |
| Kubernetes Secrets without etcd encryption at rest | NSA/CISA |
| Secrets not scoped to environments or branches in CI/CD | GitHub secret scoping |
| Missing automated certificate renewal and expiry monitoring | TLS best practices |

**3f. Logging, Monitoring, and Audit Trails**

| Check | Reference |
|-------|-----------|
| Cloud API call logging not enabled (CloudTrail, Activity Log, Audit Log) | CIS cloud benchmarks, NIST AU-2 |
| K8s API server audit policy not at `RequestResponse` level for sensitive operations | CIS K8s 3.2.x |
| Logs stored without encryption or write-once protection | NIST AU-9, CIS benchmarks |
| No alerting on security-relevant events: root login, IAM changes, firewall rule modification | NIST AU-5, SI-4 |
| Secrets or PII present in log output | NIST SP 800-190 |
| Log retention shorter than 90 days online | Compliance baseline |

**3g. Supply Chain Integrity**

| Check | Reference |
|-------|-----------|
| Container images not signed (cosign/Sigstore) | SLSA Level 2+, NIST SP 800-190 |
| No SBOM generated per build artifact | SLSA, NIST SP 800-190 |
| No build provenance attestations | SLSA Level 3 |
| Dependencies not pinned by digest/hash | Supply chain best practice |
| No admission controller verifying image signatures before deployment | Kyverno, OPA Gatekeeper |
| Third-party base images from untrusted or unverified sources | NIST SP 800-190 |
| Nix flake.lock not committed or pinned | NixOS security practice |
| Nix sops-nix or agenix not used for secrets in NixOS configs | NixOS security practice |

Nix/NixOS-specific hardening (kernel module locking, sysctl hardening, systemd service restrictions) is not covered by automated tools in the current toolchain; flag as "requires manual Nix config review" if NixOS configs are in scope.

### Phase 4: Blast Radius Assessment

For every Critical and Warning finding, model the attack path explicitly. Where a compliance framework identified in Phase 1 elevates a finding's regulatory significance, note the applicable control and its effective severity.



1. **Initial access** - What does an attacker gain from this misconfiguration directly?
2. **Lateral movement** - Can the attacker pivot from this point to adjacent systems, namespaces, or accounts?
3. **Privilege escalation** - Does this path lead to cluster-admin, cloud admin, or root?
4. **Data exposure** - What sensitive data becomes accessible (credentials, PII, private keys)?
5. **Persistence** - Can an attacker establish persistence using this vector?
6. **Blast radius scope** - Rate as: single resource / single service / single cluster / entire environment / cross-environment

Containment factors to note: network policies that limit lateral movement, log monitoring that would detect exploitation, admission controllers that block escalation.

### Phase 5: Prioritised Report

Use Batfink's standard Shield Assessment format (defined in Batfink's system prompt) with these additions:

**Methodology** - Phases completed, tools run (or not available), infrastructure scope covered, explicit limitations (e.g., "live cluster not accessible, manifests only", "cloud API access not available", "Nix configs not in scope").

**Attack Path Summary** - Synthesise the single highest-impact chain from the Phase 4 blast radius models: initial entry point, pivots, and terminal impact. One paragraph maximum.

**Repeat-Offender Patterns** - Systemic weaknesses appearing across multiple components (e.g., "no NetworkPolicies in any namespace", "all workflows use `permissions: write-all`", "all containers run as root"). These require architectural fixes, not per-resource patches.

**Remediation Roadmap** - Prioritised fix list ordered by blast radius first, then remediation effort. Group related findings. Include the specific tool or configuration change required for each item.

Write the completed report to the output file specified in the command argument.

### Constraints

- Assess blast radius before assigning severity; exploitability and impact outrank compliance checklist order
- Triage all seven infrastructure domains from Phase 3 before closing the audit
- Flag items requiring live cluster access, cloud API access, or runtime data explicitly
- Never report a finding as Exposed or Weakened without a viable attack path; if no exploitable path exists, do not report it as a finding - classify it as a Reinforcement Opportunity
- Reference the specific CIS control, NIST control family, or framework section for every Critical or Warning finding
