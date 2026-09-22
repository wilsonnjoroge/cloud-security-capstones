# Trust Boundaries — AWS Capstone

## Purpose

This document enumerates every trust boundary the request path crosses, the controls that enforce each boundary, and what an attacker would have to defeat to cross it improperly.

It is the detailed companion to `docs/architecture/architecture-overview.md`. The Architecture Overview is authoritative for the overall request path and TLS architecture; this document goes one level deeper on each trust boundary.

The deliberate CloudFront → Public ALB HTTP hop is an explicit capstone design decision and is not treated as an accidental TLS gap. The rationale and production remediation are documented in the Architecture Overview.

## Boundary Inventory

### Boundary Crossing Summary

| # | Boundary                | Layer 1 Control                                 | Layer 2 Control                                                        | Encrypted?          |
| - | ----------------------- | ----------------------------------------------- | ---------------------------------------------------------------------- | ------------------- |
| 1 | Internet → CloudFront   | WAF Web ACL                                     | CloudFront viewer TLS                                                  | Yes                 |
| 2 | CloudFront → Public ALB | SG restricted to CloudFront managed prefix list | Explicitly documented architectural limitation                         | **No — deliberate** |
| 3 | Public ALB → Web tier   | SG: `public_alb` SG only                        | TLS with tier-managed certificate                                      | Yes                 |
| 4 | Web tier → Internal ALB | SG: `web` SG only                               | Internal-only ALB + TLS                                                | Yes                 |
| 5 | Internal ALB → App tier | SG: `internal_alb` SG only                      | TLS with tier-managed certificate                                      | Yes                 |
| 6 | App tier → RDS          | SG: `app` SG only                               | RDS private accessibility + forced TLS + least-privilege DB credential | Yes                 |
| 7 | App tier → Redis        | SG: `app` SG only                               | Transit encryption + AUTH token                                        | Yes                 |
| 8 | Data subnet → Internet  | No internet route                               | No NAT/IGW path from DB subnets                                        | N/A                 |

---

## 1. Internet → CloudFront

**What crosses here:**

Anonymous, unauthenticated internet traffic enters the application through CloudFront.

**Enforced by:**

* AWS WAF Web ACL attached to the CloudFront distribution.
* AWS managed rule groups:

  * `AWSManagedRulesCommonRuleSet`
  * `AWSManagedRulesKnownBadInputsRuleSet`
* CloudFront viewer-side TLS using the distribution's default certificate.

The WAF provides the first application-facing security control before traffic reaches the origin.

**Not enforced by:**

Application-level authentication.

Anyone on the internet can reach the CloudFront distribution. Authentication and authorization remain application responsibilities.

This boundary therefore provides **network-edge filtering and encrypted transport**, not identity enforcement.

---

## 2. CloudFront → Public ALB

**What crosses here:**

Requests that CloudFront has accepted and forwards to the Public ALB origin.

**Enforced by:**

* Public ALB security group.
* Port 80 ingress is restricted to the AWS-managed CloudFront origin-facing prefix list.
* The prefix list is resolved dynamically rather than maintained as a manually maintained CIDR list.
* The ALB does not accept unrestricted internet ingress.

**Encryption:**

**Plain HTTP by deliberate design.**

CloudFront terminates viewer TLS at the edge. Because this capstone does not own a domain, it does not have the publicly trusted origin certificate required for the standard CloudFront HTTPS-to-origin model.

The internal/self-signed certificates used elsewhere in the architecture are therefore not substituted into this hop.

The complete rationale and production remediation are documented in:

`docs/architecture/architecture-overview.md`

### Security significance

Because this hop is not encrypted, the Public ALB security-group restriction is particularly important.

The ALB must not be exposed through a general:

```text
0.0.0.0/0 → TCP/80
```

rule.

The intended control is:

```text
CloudFront origin-facing prefix list → TCP/80 → Public ALB
```

### Accepted capstone limitation

An attacker who discovers the Public ALB DNS name cannot simply connect from an arbitrary internet source because the security group restricts ingress to the CloudFront managed prefix list.

The architecture nevertheless accepts that this does not provide cryptographic proof that every request reaching the ALB originated from CloudFront.

This is an explicit capstone limitation.

### Production remediation

Production would close this limitation by:

1. Owning a domain.
2. Obtaining a publicly trusted ACM certificate.
3. Configuring the CloudFront origin connection for HTTPS.
4. Enforcing HTTPS-only communication between CloudFront and the Public ALB.

---

## 3. Public ALB → Web Tier

**What crosses here:**

Traffic forwarded by the Public ALB to individual web-tier instances.

**Enforced by:**

* Web-tier security group.
* Inbound traffic is permitted on `web_listen_port` (`8443`) only from the `public_alb` security group.
* The relationship is SG-to-SG rather than CIDR-based, so it remains valid as the web ASG scales.

**Encryption:**

TLS using the tier-managed certificate.

Unlike the CloudFront → Public ALB hop, this connection is encrypted because both endpoints are infrastructure controlled by the project and the web tier's trust configuration is managed through Ansible.

An attacker therefore needs to defeat both:

* the network-layer SG boundary, and
* the TLS/trust configuration

to improperly cross this boundary.

---

## 4. Web Tier → Internal ALB

**What crosses here:**

Application traffic originating from the web tier and destined for the internal application path.

**Enforced by:**

* Internal ALB security group.
* Port 443 is permitted only from the `web` security group.
* The Internal ALB is internal-only.

**Encryption:**

TLS using the tier-managed certificate.

### Network isolation

The Internal ALB is not internet-facing.

It therefore does not have an internet-facing load-balancer network path. Its DNS name is usable within the appropriate private network context, but it is not a public internet endpoint.

This provides a second control beyond the security group:

```text
Internet
   X
   │
Internal ALB
```

Even if an external-facing SG rule were accidentally introduced, the load balancer would still not become internet-facing without changing its fundamental network placement/configuration.

---

## 5. Internal ALB → App Tier

**What crosses here:**

Traffic forwarded by the Internal ALB to individual app-tier instances.

**Enforced by:**

* App-tier security group.
* Inbound traffic is permitted on `app_listen_port` (`8080`) only from the `internal_alb` security group.
* No unrestricted CIDR-based application ingress is permitted.

**Encryption:**

TLS using the tier-managed certificate.

The app tier therefore has two relevant controls:

```text
Internal ALB SG → App SG
        +
      TLS
```

An attacker must defeat the network boundary and the TLS configuration to improperly cross this hop.

---

## 6. App Tier → RDS

**What crosses here:**

Database traffic originating from the app tier.

No other application tier should have access to the application database.

**Enforced by:**

* RDS security group permits TCP/3306 only from the `app` security group.
* RDS is configured with `publicly_accessible = false`.
* RDS is placed in the isolated DB subnets.
* Database connections require secure transport.
* The application uses a dedicated least-privilege database account rather than the RDS master account.

### Credential boundary

The app tier retrieves its database credential from Secrets Manager.

The app IAM role is permitted to retrieve the application DB secret.

The web-tier IAM role does not receive that permission.

Therefore:

```text
Web compromise
     │
     X
     │
App DB secret
```

A compromised web instance should not be able to obtain the application database credential merely because it exists somewhere in the same VPC.

### Important distinction

IAM controls **access to the database credential in Secrets Manager**.

The actual MySQL connection is authenticated using the dedicated database account, such as:

```text
app_svc
```

The RDS master credential is break-glass only and is not provided to the application.

---

## 7. App Tier → Redis

**What crosses here:**

Cache reads and writes originating from the application tier.

**Enforced by:**

* Redis security group permits TCP/6379 only from the `app` security group.
* Redis transit encryption is enabled.
* Redis requires authentication using the dedicated AUTH token.
* The AUTH token is stored in Secrets Manager and is accessible only to the application IAM role.

**Encryption:**

The network crossing is protected by Redis transit encryption.

At-rest encryption is a separate data-protection control and protects stored cache data rather than the network crossing itself.

The resulting boundary is:

```text
App SG
  │
  ├── TCP/6379
  │
  ▼
Redis SG
  +
TLS
  +
AUTH
```

Network reachability alone therefore does not provide sufficient access to the cache.

---

## 8. Data Subnets → Internet

### Negative Boundary

**What must not cross here:**

No outbound connection from the DB subnets to the public internet.

This protects the data tier against an internet egress path that could otherwise facilitate data exfiltration or unauthorized external communication.

**Enforced by:**

The DB subnet route tables contain no:

```text
0.0.0.0/0
```

route.

They contain only the implicit VPC-local route.

There is therefore no direct route from the DB subnets to:

* an Internet Gateway
* a NAT Gateway
* the public internet

This is intentionally enforced at the route-table layer rather than relying exclusively on security-group egress rules.

### Why route-table enforcement matters

A security group is a stateful firewall and its rules can be modified by sufficiently privileged AWS identities.

The absence of an internet route provides an additional network-layer control.

For an internet path to exist, an attacker would have to introduce the required routing and gateway/NAT path in addition to overcoming any applicable security-group restrictions.

This makes the data-tier isolation resilient against a single incorrectly permissive security-group egress rule.

---

## Trust Boundary Enforcement Model

The architecture intentionally uses multiple independent controls at the important boundaries.

The general pattern is:

```text
Network boundary
       +
Protocol encryption
       +
Identity / credential control
       +
Resource isolation
```

Not every boundary requires all four layers, but the higher-value boundaries use more than one control wherever practical.

### Example

App → RDS:

```text
App SG
   +
Private RDS
   +
No public path
   +
TLS
   +
Least-privilege DB credential
   +
Secrets Manager IAM control
```

This is preferable to treating a single security group as the entire security boundary.

---

## Validation Requirement

Every boundary documented here should map to an observable control.

Validation must verify the deployed environment rather than merely confirm that Terraform contains the expected configuration.

Relevant validation areas include:

* Security-group ingress and egress
* CloudFront origin access restriction
* Route-table isolation
* Internal ALB exposure
* RDS public accessibility
* RDS TLS enforcement
* Redis TLS enforcement
* Secrets Manager IAM access
* Application credential separation
* IMDSv2 enforcement on compute instances

The validation tooling is maintained under:

```text
scripts/validation/
```

Relevant checks include:

```text
aws-port-exposure-check.*
aws-tls-enforcement-check.*
aws-imdsv2-check.*
```

A successful configuration deployment must not be described as **validated** until the corresponding live-environment evidence exists under:

```text
evidence/validation/
```

---

## Related Documents

* `docs/architecture/architecture-overview.md`
* `docs/architecture/threat-model.md`
* `docs/architecture/dfd.md`
* `docs/security/network-security.md`
* `docs/security/iam-strategy.md`
* `docs/security/data-protection.md`
