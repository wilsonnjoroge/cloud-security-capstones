
# Threat Model: AWS Capstone

## Purpose

This document identifies the threats the architecture is designed to resist, maps each to the specific control(s) in `docs/architecture/trust-boundaries.md` and `docs/security/network-security.md` that address it, and states plainly where the architecture accepts residual risk rather than eliminating it.

It does not restate control implementation detail: that lives in the architecture, trust-boundaries, network-security, IAM, and data-protection documents. This document is the "why does this control exist" index across them.

Threats are organized using STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege), scoped per trust boundary rather than per component, since the boundaries are the architecture's actual unit of defense.

## Assets in scope

* Application data in transit and at rest (RDS, ElastiCache).
* Application and infrastructure credentials (DB credentials, Redis AUTH token, RDS master credential).
* Compute instances (web tier, app tier) and their IAM role permissions.
* Ansible bundle (S3): the configuration-delivery supply chain for every instance.
* Network path integrity: the assumption that traffic reaching a given tier actually originated from the expected upstream tier.
* Application availability and the availability of the network path between application tiers.

## Out of scope for this capstone

* Application-layer logic vulnerabilities (SQLi, XSS, business-logic flaws) beyond what WAF managed rule groups catch generically: this is infrastructure/platform threat modeling, not a code-level security review of the application itself.
* Insider threat from AWS account-level IAM administrators (someone with `iam:*`/`ec2:*` at the account root can defeat any control here: that's an organizational control, not an architectural one).
* Physical/hardware-layer AWS threats: accepted as AWS's shared-responsibility scope.
* Full volumetric DDoS protection and enterprise-scale availability engineering beyond the controls explicitly implemented in this capstone.

## Threats by boundary

### Boundary 1: Internet → CloudFront

| Threat (STRIDE)                    | Description                                                                      | Control                                                                                                       | Status                                                                 |
| ---------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Tampering / Information Disclosure | Generic web exploitation (SQLi patterns, known bad payloads) reaching the origin | WAF Web ACL: `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`                           | Planned: rule action (count vs. block) not yet finalized in Terraform |
| Information Disclosure / Tampering | Plaintext viewer traffic                                                         | CloudFront viewer HTTPS using the default CloudFront TLS certificate                                          | Planned                                                                |
| Denial of Service                  | High-volume or abusive HTTP requests reaching the application edge               | CloudFront distribution and WAF provide the edge enforcement point for traffic filtering and request handling | Planned: this does not claim comprehensive volumetric DDoS protection |
| Spoofing                           | Client impersonation / no identity check at this layer                           | None: explicitly out of scope here; application owns authentication                                          | Accepted: not this boundary's job                                     |

**Residual risk:** WAF managed rule groups are generic signature matching, not a substitute for application-level input validation. If the rule action ends up as "count" rather than "block" during initial rollout, WAF will observe rather than prevent matching requests. That is a real residual risk and must be tracked rather than silently assumed to be blocked.

### Boundary 2: CloudFront → Public ALB

| Threat (STRIDE)                    | Description                                                                              | Control                                                                                                 | Status                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Spoofing                           | Direct connection to the Public ALB, bypassing CloudFront/WAF entirely                   | Public ALB SG: ingress restricted to the CloudFront managed prefix list, port 80 only                   | Planned                                                     |
| Information Disclosure / Tampering | Traffic on this hop is plaintext: anything observing this segment can read or modify it | **Accepted, deliberate**: see `architecture-overview.md` TLS rationale                                 | Accepted capstone limitation                                |
| Denial of Service                  | Direct request flooding against the origin ALB                                           | Public ALB ingress is restricted to the CloudFront managed prefix list rather than `0.0.0.0/0`          | Planned: does not constitute comprehensive DDoS protection |
| Spoofing (residual)                | A source within the CloudFront prefix-list range that is not actually CloudFront         | SG restriction narrows the permitted source space but does not cryptographically verify origin identity | Accepted, documented                                        |

**Residual risk: stated plainly:** this is the weakest boundary in the architecture by design.

The SG-to-prefix-list restriction is a real control: the ALB is not open to the internet: but it is not cryptographic proof of origin identity. A source able to originate traffic from an address covered by the CloudFront origin-facing prefix list could potentially send requests directly to the ALB and bypass CloudFront/WAF processing.

An attacker reaching the Public ALB still has to defeat the subsequent boundaries before reaching protected tiers or data.

Production remediation is an owned domain with a publicly trusted ACM certificate and an HTTPS-only CloudFront-to-origin policy. This limitation is intentionally accepted in the capstone and must not be reframed as equivalent to end-to-end TLS.

### Boundary 3: Public ALB → Web tier

| Threat (STRIDE)                    | Description                                                                  | Control                                                                                    | Status                         |
| ---------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------ |
| Spoofing                           | Traffic reaching web tier without transiting the Public ALB                  | Web SG: ingress on 8443 from `public_alb` SG only                                          | Planned                        |
| Information Disclosure / Tampering | Traffic interception or modification in flight                               | TLS, tier-managed certificate delivered through Ansible                                    | Planned                        |
| Denial of Service                  | Excessive traffic reaching individual web instances                          | ALB distributes traffic across the web ASG; upstream edge controls reduce unwanted traffic | Planned                        |
| Elevation of Privilege             | Compromised web instance attempting to obtain privileges beyond the web tier | Web instances use a restricted IAM role with no app-tier or data-tier permissions          | Planned, see `iam-strategy.md` |

### Boundary 4: Web tier → Internal ALB

| Threat (STRIDE)                    | Description                                                      | Control                                                                                       | Status  |
| ---------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------- |
| Spoofing                           | Non-web-tier source reaching the internal ALB                    | Internal ALB SG: ingress on 443 from `web` SG only                                            | Planned |
| Elevation of Privilege             | Internal ALB exposed to the internet due to misconfiguration     | Internal ALB is internal-only: no internet-facing network path exists regardless of SG state | Planned |
| Information Disclosure / Tampering | Traffic interception in flight                                   | TLS, tier-managed certificate                                                                 | Planned |
| Denial of Service                  | Excessive requests from a compromised or malfunctioning web tier | Internal ALB and downstream app ASG provide controlled load distribution                      | Planned |

### Boundary 5: Internal ALB → App tier

| Threat (STRIDE)                    | Description                                                                                                         | Control                                                                          | Status  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------- |
| Spoofing                           | Non-internal-ALB source reaching app tier directly                                                                  | App SG: ingress on 8080 from `internal_alb` SG only                              | Planned |
| Information Disclosure / Tampering | Traffic interception in flight                                                                                      | TLS, tier-managed certificate                                                    | Planned |
| Denial of Service                  | Excessive requests reaching the app tier                                                                            | Internal ALB distributes permitted traffic across the app ASG                    | Planned |
| Elevation of Privilege             | A compromised web-tier instance uses its network position to reach the app tier directly, skipping the internal ALB | App SG ingress is scoped to the `internal_alb` SG specifically, not the `web` SG | Planned |

The SG relationship means a compromised web instance does not receive an SG-authorized direct path to the app instances.

### Boundary 6: App tier → RDS

| Threat (STRIDE)                    | Description                                                        | Control                                                                                                                                                             | Status                         |
| ---------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| Spoofing                           | Non-app-tier source connecting to RDS                              | RDS SG: ingress on 3306 from `app` SG only; `publicly_accessible = false`                                                                                           | Planned                        |
| Information Disclosure / Tampering | Unencrypted DB connection                                          | `require_secure_transport = ON` at the parameter-group level                                                                                                        | Planned                        |
| Elevation of Privilege             | A compromised web instance obtaining DB access                     | Web IAM role has no Secrets Manager read permission for the application DB secret                                                                                   | Planned, see `iam-strategy.md` |
| Elevation of Privilege             | A compromised app instance obtaining the RDS master credential     | App IAM role can retrieve only the application DB credential and Redis AUTH token; the master credential is stored separately and is not accessible to the app role | Planned                        |
| Repudiation                        | No record of database activity                                     | CloudWatch log exports (audit/error/general/slowquery) enabled for RDS                                                                                              | Planned                        |
| Denial of Service                  | Excessive or unauthorized connection attempts against the database | RDS SG restricts inbound access to the app SG; application access uses the dedicated `app_svc` database account                                                     | Planned                        |

**Note on credential vs. network control:** the IAM policy governs retrieval of the credential from Secrets Manager. It does not authenticate the MySQL session itself.

The MySQL session is authenticated using the dedicated `app_svc` database account. This is a separate control layer.

An attacker who somehow obtained the `app_svc` password through a means other than Secrets Manager would still need to satisfy the network and TLS controls before establishing the database connection. The controls are layered rather than redundant.

The RDS master credential is reserved for break-glass administrative use and is not the application's database credential.

### Boundary 7: App tier → Redis

| Threat (STRIDE)                    | Description                                                                | Control                                          | Status  |
| ---------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------ | ------- |
| Spoofing                           | Non-app-tier source connecting to Redis                                    | Redis SG: ingress on 6379 from `app` SG only     | Planned |
| Information Disclosure / Tampering | Unencrypted cache traffic or unauthenticated connection                    | Transit encryption enabled + AUTH token required | Planned |
| Elevation of Privilege             | Compromised web instance reads or modifies cached session/application data | Web tier has no SG-authorized path to Redis      | Planned |
| Denial of Service                  | Unauthorized or excessive Redis connection attempts                        | Redis SG restricts inbound access to the app SG  | Planned |

Transit encryption protects the network crossing; the AUTH token provides the Redis authentication layer. These are independent controls.

### Boundary 8: Data subnets → Internet (negative boundary)

| Threat (STRIDE)                   | Description                                                                                      | Control                                                                                     | Status  |
| --------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- | ------- |
| Information Disclosure            | Data exfiltration via an outbound connection from a compromised RDS/ElastiCache-adjacent process | No default route from DB subnets to any IGW/NAT Gateway: enforced at the route-table layer | Planned |
| Denial of Service / Network abuse | Data-tier resources attempting to establish arbitrary internet connections                       | No internet egress route exists from the DB subnets                                         | Planned |

**Why this is framed as "no internet egress path" rather than anti-C2:** RDS and ElastiCache are managed services: there is no arbitrary code-execution surface on the service instances equivalent to an EC2 host.

The actual property being defended is narrower and more precise: the DB subnets have no internet route, regardless of what attempts to use them.

## Cross-cutting threats

| Threat                                                   | Description                                                                                              | Control                                                                                                                                                                                           | Status                                                     |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Supply-chain compromise via Ansible bundle               | A tampered playbook in the S3 bundle gets pulled and applied to instances                                | Bundle bucket is private, versioned, and encrypted under the `ansible-bundle` KMS key; bucket policy denies non-TLS requests; access is performed through the intended SSM/State Manager workflow | Planned                                                    |
| Instance metadata credential theft (SSRF-style)          | An application-layer vulnerability is used to query IMDS for instance IAM credentials                    | IMDSv2 enforced with `http_tokens = "required"` and `http_put_response_hop_limit = 1` on both tiers' launch templates                                                                             | Planned, see `scripts/validation/aws-imdsv2-check.*`       |
| Persistent SSH-based access as a standing attack surface | Long-lived SSH keys or bastion hosts become persistent targets                                           | No SSH anywhere: SSM Session Manager only; no inbound SSH port is required                                                                                                                       | Planned                                                    |
| Configuration drift silently reopening a closed boundary | A manual console change adds a broad SG rule or otherwise alters network configuration                   | Terraform remains the source of truth for network resources; SSM State Manager re-applies Ansible instance configuration every 7 days                                                             | Planned                                                    |
| Terraform-managed resource drift                         | An out-of-band change modifies an SG, route table, subnet, endpoint, or other Terraform-managed resource | Periodic Terraform plan/review or dedicated drift-detection tooling                                                                                                                               | Planned: automated remediation is not currently specified |
| RDS master credential misuse                             | Master credential is used for routine application access instead of break-glass administration           | Master credential is stored separately from the application DB credential; application IAM policies do not reference it                                                                           | Planned                                                    |
| IAM credential abuse after instance compromise           | An attacker obtains temporary credentials from a compromised EC2 instance                                | IMDSv2, least-privilege instance roles, restricted Secrets Manager access, and separation of web/app IAM permissions                                                                              | Planned                                                    |
| AWS-service traffic interception through public egress   | Private workloads access AWS services through public/NAT paths unnecessarily                             | VPC endpoints for S3, SSM, SSMMessages, EC2Messages, Secrets Manager, and CloudWatch Logs                                                                                                         | Planned                                                    |

### Ansible bundle integrity limitation

S3 versioning provides historical versions and recovery capability, while KMS encryption protects the confidentiality of the stored bundle.

Neither mechanism alone proves that the bundle being executed is authentic.

Therefore, the architecture does **not** claim that S3 versioning is a complete supply-chain integrity control. If stronger bundle authenticity is required, additional controls such as cryptographic signing and signature verification should be introduced as a future enhancement.

## Explicitly accepted risks

The following risks must not be silently "fixed" without an architectural decision:

1. **CloudFront → Public ALB is plaintext HTTP.** Accepted for this capstone; production remediation requires an owned domain, publicly trusted origin certificate, and HTTPS-only origin communication.

2. **WAF managed rule group action (count vs. block) is not yet finalized.** Until the WAF Terraform is implemented and validated, do not assume matching requests are being blocked.

3. **Terraform-managed network resource drift detection is not yet specified.** Ansible's seven-day reapplication covers instance configuration, not SGs, route tables, VPC endpoints, or other Terraform-managed infrastructure.

4. **Application-layer vulnerabilities are out of scope for this document.** WAF managed rules provide generic filtering but do not replace secure application development and application-layer testing.

5. **Ansible bundle authenticity is not fully established by S3 versioning and encryption alone.** Stronger cryptographic supply-chain verification is a future enhancement unless separately implemented.

6. **Full volumetric DDoS protection is not claimed.** CloudFront/WAF and the architecture's network restrictions reduce exposure and provide edge controls, but this capstone does not claim enterprise-scale DDoS resilience.

## Status model

Consistent with `network-security.md`, every control referenced above is **Planned** until it progresses through the following states:

* **Planned**: documented as intended architecture/control.
* **Implemented**: deployed and configured in the AWS environment.
* **Validated**: deployed/configured and supported by live evidence under `evidence/validation/`.

This document does not claim any control is validated merely because it appears here.

Validation claims belong to the evidence produced by the validation tooling.

## Related documents

* `docs/architecture/architecture-overview.md`: request path and TLS decision rationale
* `docs/architecture/trust-boundaries.md`: per-boundary control detail
* `docs/security/network-security.md`: network implementation reference
* `docs/security/iam-strategy.md`: identity and least-privilege detail
* `docs/security/data-protection.md`: encryption and credential-handling detail
* `scripts/validation/`: live validation tooling
* `evidence/validation/`: evidence supporting validated claims
