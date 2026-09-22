
# Network Security: AWS Capstone

## Purpose

This document specifies the network-layer controls implementing the trust boundaries defined in `docs/architecture/trust-boundaries.md`. Where that document explains *why* each boundary exists and what an attacker would need to defeat, this document specifies the concrete resources and settings that implement it: the reference for anyone writing or reviewing `modules/network/` and `modules/security/` Terraform.

The controls described here implement the approved architecture. They are not considered validated merely because they are declared in Terraform; live validation evidence must exist under `evidence/validation/`.

## VPC and subnet design

**VPC:** `10.0.0.0/16` (`vpc_cidr` variable), with DNS support and DNS hostnames both enabled.

**Four-tier, two-AZ subnet layout (8 subnets):**

| Tier   | AZ-a           | AZ-b           | Internet path                                   |
| ------ | -------------- | -------------- | ----------------------------------------------- |
| Public | `10.0.0.0/24`  | `10.0.1.0/24`  | IGW (NAT gateways only: no workload instances) |
| Web    | `10.0.10.0/24` | `10.0.11.0/24` | Via own AZ's NAT Gateway                        |
| App    | `10.0.20.0/24` | `10.0.21.0/24` | Via own AZ's NAT Gateway                        |
| DB     | `10.0.30.0/24` | `10.0.31.0/24` | **None: no default route**                     |

The tier separation is the primary network-level segmentation control. It exists independently of security groups: even before any SG rule is evaluated, an instance in the App subnet has no routable path to leave the DB tier except through the routes available to that subnet, while workload instances never sit in the Public subnet. The Public subnet exists only to host NAT Gateways.

## Routing: the DB tier's real enforcement mechanism

This is worth stating plainly because it is easy to under-value next to security groups:

**The DB subnets' route tables have no `0.0.0.0/0` entry of any kind.**

There is no NAT Gateway route and no IGW route. The only applicable route is the implicit VPC-local route.

This means the "data tier has no internet egress path" property is enforced at the routing layer, independently of security-group configuration. Even if an associated security group were accidentally given broad egress permissions, there would still be no default route from the DB subnets to an IGW or NAT Gateway.

This is deliberately the strongest available network control for this requirement and is why the Architecture Overview and Trust Boundaries documents identify the property as being enforced at the route-table level, not only through security groups.

### Public/Web/App route tables

* **Public:** one shared route table with `0.0.0.0/0 → IGW`.
* **Web:** one route table per AZ, each routing `0.0.0.0/0` to that AZ's own NAT Gateway.
* **App:** one route table per AZ, each routing `0.0.0.0/0` to that AZ's own NAT Gateway.
* **DB:** one route table per AZ with no default route.

The per-AZ NAT design avoids making private-tier internet egress in one AZ dependent on the NAT Gateway in another AZ. A NAT Gateway failure or AZ-level event therefore does not inherently remove outbound connectivity for the corresponding private tier in the other AZ.

NAT Gateway access is retained for permitted non-AWS-service outbound traffic. AWS-service traffic for services with configured VPC endpoints should use those endpoints instead.

## VPC Endpoints: keeping AWS-service traffic off the public internet path

Web and App instances have NAT Gateway egress available, but AWS-service traffic for the services required by the security architecture is deliberately routed through VPC endpoints.

The endpoint design includes:

| Endpoint        | Type      | Purpose                                            | Consumers |
| --------------- | --------- | -------------------------------------------------- | --------- |
| S3              | Gateway   | Ansible bundle retrieval without NAT               | Web, App  |
| SSM             | Interface | Systems Manager control-plane communication        | Web, App  |
| SSMMessages     | Interface | Systems Manager Agent data channel                 | Web, App  |
| EC2Messages     | Interface | Systems Manager Agent communication where required | Web, App  |
| Secrets Manager | Interface | Application secret retrieval                       | App       |
| CloudWatch Logs | Interface | CloudWatch Agent log delivery                      | Web, App  |

The S3 gateway endpoint is route-based and does not use a security group.

The interface endpoints use a dedicated endpoint security group.

### Endpoint security group

The endpoint security group permits:

* Ingress TCP `443` from the VPC CIDR only.
* No ingress from the internet.
* No public-facing access.

This keeps interface endpoint access restricted to resources already inside the VPC.

### Why this matters

Ansible bundle retrieval, Systems Manager communication, Secrets Manager retrieval, and CloudWatch Logs delivery do not need to traverse the NAT Gateway when the corresponding VPC endpoints are available.

This reduces the exposed network path for AWS-service communication and provides a clearer separation between:

* private AWS-service access through VPC endpoints; and
* permitted general outbound access through NAT Gateway.

## Security groups: full ruleset

This table is the security-group source of truth. `trust-boundaries.md` explains the reasoning behind each boundary; this document specifies the implementation.

| Security Group  | Direction | Port | Source / Destination           |
| --------------- | --------- | ---: | ------------------------------ |
| `public_alb`    | Ingress   |   80 | CloudFront managed prefix list |
| `public_alb`    | Egress    | 8443 | `web` SG                       |
| `web`           | Ingress   | 8443 | `public_alb` SG                |
| `web`           | Egress    |  443 | VPC endpoint SG                |
| `web`           | Egress    |  443 | `internal_alb` SG              |
| `internal_alb`  | Ingress   |  443 | `web` SG                       |
| `internal_alb`  | Egress    | 8080 | `app` SG                       |
| `app`           | Ingress   | 8080 | `internal_alb` SG              |
| `app`           | Egress    |  443 | VPC endpoint SG                |
| `app`           | Egress    | 3306 | `rds` SG                       |
| `app`           | Egress    | 6379 | `redis` SG                     |
| `rds`           | Ingress   | 3306 | `app` SG                       |
| `redis`         | Ingress   | 6379 | `app` SG                       |
| VPC endpoint SG | Ingress   |  443 | VPC CIDR only                  |

The Web-to-Internal-ALB rule is intentionally represented separately from endpoint access because it is application traffic rather than AWS-service traffic.

The endpoint SG is shared by the required interface endpoints, while the Secrets Manager endpoint is consumed specifically by the App tier.

### Security-group rules that apply across the design

* No security group has an ingress rule sourced from `0.0.0.0/0`.
* The Public ALB is the only internet-facing workload entry point, and even its ingress is restricted to the AWS-managed CloudFront origin-facing prefix list.
* Ingress rules for workload-to-workload communication reference security groups rather than CIDR ranges wherever possible.
* The VPC endpoint security group deliberately uses the VPC CIDR because interface endpoints are shared AWS-service access points rather than workload instances.
* Egress is scoped to a specific destination security group and port wherever the destination is SG-bounded infrastructure.
* Broad `0.0.0.0/0` egress should not be used as a substitute for explicit destination rules where the destination is known.
* DB-tier internet isolation is enforced independently through the absence of a default route.

## Port and TLS note

**CloudFront → Public ALB is HTTP on port 80 by deliberate architectural decision.**

The `public_alb` ingress rule therefore uses port 80.

This is **not a configuration mistake**.

The approved request path is:

1. Client → CloudFront: HTTPS
2. CloudFront → Public ALB: HTTP/80
3. Public ALB → Web: HTTPS/8443
4. Web → Internal ALB: HTTPS/443
5. Internal ALB → App: HTTPS/8080
6. App → RDS: TLS-required MySQL/3306
7. App → Redis: TLS-enabled Redis/6379

The CloudFront-to-ALB hop remains plaintext because the capstone does not currently have an owned public domain and therefore does not implement the production-grade public origin certificate arrangement.

For a production deployment, the remediation is:

* use an owned domain;
* issue a publicly trusted ACM certificate for the origin;
* configure CloudFront to use HTTPS to the Public ALB; and
* remove the deliberate HTTP origin limitation.

Do not infer TLS from the port number alone. Port 80 on the first hop is intentionally plaintext; the subsequent listener ports represent the TLS-enabled internal hops documented by the architecture.

## Network visibility

### VPC Flow Logs

VPC Flow Logs are configured with:

* `traffic_type = "ALL"` to capture both ACCEPT and REJECT traffic;
* VPC-wide scope;
* delivery to a dedicated CloudWatch Logs log group;
* 30-day retention;
* encryption using the `flow-logs` KMS key.

REJECT entries are particularly valuable operationally because they provide evidence of traffic attempts that the network architecture does not permit, including unexpected attempts to reach protected tiers or the Public ALB from unauthorized sources.

A dedicated IAM role handles flow-log delivery and has only the permissions required for that delivery function.

## Validation

Network-security claims are intended to be checked against the deployed environment rather than accepted solely from Terraform configuration.

### Port and exposure validation

`scripts/validation/aws-port-exposure-check.*`

The validation should verify at minimum:

* no unexpected `0.0.0.0/0` ingress rules exist;
* Public ALB ingress is restricted to the CloudFront managed prefix list;
* internal workload tiers are not directly internet exposed;
* DB subnet route tables have no `0.0.0.0/0` route;
* the intended security-group trust chain exists; and
* the expected protected ports are not exposed outside their intended upstream security groups.

### TLS validation

`scripts/validation/aws-tls-enforcement-check.*`

The validation should verify that TLS is actually presented and required on the protected application/data hops:

* Public ALB → Web: 8443
* Web → Internal ALB: 443
* Internal ALB → App: 8080
* App → RDS: 3306 with TLS required
* App → Redis: 6379 with transit encryption

The check must also explicitly recognize that:

* CloudFront → Public ALB uses HTTP/80 by deliberate architectural design.

This prevents the intentional architecture decision from being incorrectly reported as a security-validation failure.

### Evidence requirement

A successful Terraform deployment is not, by itself, validation evidence.

Validated claims must be supported by live evidence stored under:

```text
evidence/validation/
```

The repository should distinguish between:

* **Planned**: documented but not implemented;
* **Implemented**: deployed/configured; and
* **Validated**: deployed/configured and supported by live evidence.

## Module ownership

The controls described here map to the approved six-module Terraform structure:

```text
infrastructure/modules/
├── network/
├── security/
├── compute/
├── data/
├── edge/
└── observability/
```

Network-layer responsibilities primarily belong to:

* `modules/network/`: VPC, subnets, route tables, NAT, IGW, and VPC endpoints.
* `modules/security/`: security groups and related network-access controls.
* `modules/observability/`: VPC Flow Logs and associated logging infrastructure.

The environment layer under `infrastructure/environments/dev/` should wire these modules together and provide environment-specific configuration. It should not directly declare the underlying network resources.

Future UAT and DR/DC environments are structural placeholders only until separately implemented and validated. Their presence in the repository must not be interpreted as evidence that those environments or replication paths are currently deployed.

## Related documents

* `docs/architecture/architecture-overview.md`: request path and TLS decision rationale
* `docs/architecture/trust-boundaries.md`: why each boundary exists and what it defends against
* `docs/security/iam-strategy.md`: identity and least-privilege controls
* `docs/security/data-protection.md`: encryption and data-protection controls
* `scripts/validation/`: live network and security validation
* `evidence/validation/`: evidence supporting validated claims
