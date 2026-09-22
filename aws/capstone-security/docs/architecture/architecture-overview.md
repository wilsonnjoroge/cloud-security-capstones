# Architecture Overview: AWS Capstone

## Purpose

This document is the build specification for the AWS capstone. It describes the target architecture in full: anyone should be able to recreate this environment from this document and the accompanying `infrastructure/`, `ansible/`, and `scripts/` directories alone.

## What this capstone demonstrates

A three-tier web application on AWS, built to show that layered trust boundaries, least-privilege IAM per tier, config-managed (not SSH-managed) compute, and scoped encryption-at-rest can be applied consistently as a coherent set of principles. This is capstone 1 of 3; the same principle set is reapplied to Azure and GCP, with a root README mapping equivalent controls across all three clouds.

## Repository structure

```text
cloud-security-capstones/
├── README.md
├── aws/
│   └── capstone-security/
│       ├── infrastructure/
│       │   ├── modules/
│       │   │   ├── network/          # VPC, subnets, routing, endpoints
│       │   │   ├── security/         # SGs, IAM, KMS
│       │   │   ├── compute/          # Launch templates, ASGs, SSM/Ansible delivery
│       │   │   ├── data/             # RDS, ElastiCache, secrets
│       │   │   ├── edge/             # ALBs, CloudFront, WAF
│       │   │   └── observability/    # VPC flow logs
│       │   └── environments/
│       │       └── dev/              # Wiring layer only: no resources of its own
│       ├── ansible/
│       ├── scripts/
│       ├── tests/
│       ├── evidence/
│       ├── docs/
│       ├── diagrams/
│       └── .github/workflows/
├── azure/capstone-security/
├── gcp/capstone-security/
└── shared/
```

**Governing principle:** modules contain infrastructure logic; environments contain configuration and wire modules together. `environments/dev/main.tf` never declares a resource directly: it only instantiates modules and passes variables between them. No module reaches into another module's state; every cross-module dependency is an explicit output → input wire.

```text
inputs → [ MODULE ] → outputs
```

Only `dev` exists today. `staging`/`prod` are added deliberately once `dev` is proven: not created empty in advance.

## Request path

1. **CloudFront**: entry point, `*.cloudfront.net` default certificate. WAF Web ACL attached (AWS managed rule groups: Common Rule Set, Known Bad Inputs).
2. **Public ALB**: internet-facing. Security group ingress restricted to the CloudFront managed prefix list only, looked up dynamically: never open internet.
3. **Web tier**: Auto Scaling Group, private subnets, minimum 2 instances at creation (one per AZ), scaling on traffic from there. Reached only from the public ALB.
4. **Internal ALB**: internal-only, reached only from the web tier.
5. **App tier**: Auto Scaling Group, private subnets, minimum 2 instances at creation (one per AZ), scaling on traffic from there. Reached only from the internal ALB.
6. **Data tier**: RDS (MySQL) and ElastiCache (Redis), reached only from the app tier, in subnets with no route to the internet at all: enforced at the route-table level, not just security groups.

## TLS architecture: decision and rationale

This project does not own a domain, which constrains what's achievable end-to-end. The chain is split into two zones:

**CloudFront → Public ALB (edge-terminated, plain HTTP behind CloudFront):**
CloudFront only accepts origin certificates that chain to a publicly trusted CA (the same list Mozilla trusts). It rejects self-signed certificates outright, and AWS Private CA certificates are *not* on that public trust list either: CloudFront has no "custom trust store" option for standard origin server-certificate validation (that feature exists only for CloudFront's separate mTLS-to-origin capability, which authenticates the *client* side, not the origin's server cert). Obtaining a publicly trusted cert requires ACM domain validation, which requires owning a domain. Since this capstone has neither, CloudFront terminates TLS at the edge using its default certificate, and the CloudFront→Public ALB hop runs plain HTTP.

**Every hop after the Public ALB (end-to-end TLS, self-signed, Ansible-managed):**
From the Public ALB onward, every hop is inside infrastructure this project controls, so it can decide what to trust:
- Public ALB → Web tier: TLS, `web_listen_port` (8443)
- Web tier → Internal ALB: TLS, port 443
- Internal ALB → App tier: TLS, `app_listen_port` (8080)

Certificates for these hops are self-signed, generated and rotated by Ansible (`base-tasks.yml`), with each tier's trust store explicitly configured via Ansible to trust the relevant peer certificate. This is a deliberate, capstone-scope decision, not an oversight.

**Documented production gap:** to close the remaining hop, production would require (1) an owned domain, (2) an ACM public certificate issued for the Public ALB, (3) CloudFront's origin protocol policy set to HTTPS-only. This is a known, explicit limitation of the current design: not a silent gap.

## Trust boundaries

| Boundary | Enforced by |
|---|---|
| Internet → CloudFront | WAF Web ACL, CloudFront default TLS |
| CloudFront → Public ALB | Public ALB SG: ingress restricted to CloudFront prefix list only. Plain HTTP (see TLS section above) |
| Public ALB → Web tier | Web tier SG: ingress only from Public ALB SG. TLS |
| Web tier → Internal ALB | Internal ALB SG: ingress only from Web tier SG. TLS |
| Internal ALB → App tier | App tier SG: ingress only from Internal ALB SG. TLS |
| App tier → RDS | RDS SG: ingress only from App tier SG, port 3306 |
| App tier → Redis | Redis SG: ingress only from App tier SG, port 6379 |
| Data tier → internet | No route: DB subnets' route table has no `0.0.0.0/0` entry |

## Security groups: trust chain

Each tier accepts inbound from exactly one source. No security group ever uses `0.0.0.0/0` for ingress; egress is scoped to the VPC CIDR (or specific ports), never wide open.

| SG | Ingress | Egress |
|---|---|---|
| `public_alb` | 80 from CloudFront managed prefix list only | `web_listen_port` (8443) to `web` SG |
| `web` | `web_listen_port` (8443) from `public_alb` SG | 443 to `internal_alb` SG |
| `internal_alb` | 443 from `web` SG | `app_listen_port` (8080) to `app` SG |
| `app` | `app_listen_port` (8080) from `internal_alb` SG | 443 to VPC-endpoint traffic; 3306 to `rds` SG; 6379 to `redis` SG |
| `rds` | `db_port` (3306) from `app` SG | none |
| `redis` | `redis_port` (6379) from `app` SG | none |
| VPC endpoint SG | 443 from VPC CIDR only | none |

> **Fixed from earlier draft:** the `public_alb`→`web` ingress port previously implied HTTPS on the CloudFront hop (contradicting the edge-terminated decision above): corrected to port 80 on that first hop. The `app` SG egress previously omitted RDS/Redis entirely, which would have made the app tier unable to reach its own database: added.

## Compute: Auto Scaling, per tier

Each tier (web, app) is built as:

- One `aws_launch_template`: AMI, instance type, IAM instance profile, security group, IMDSv2 enforced (`http_tokens = "required"`, `http_put_response_hop_limit = 1`), root EBS volume encrypted under the tier-appropriate KMS key.
- One `aws_autoscaling_group`: spans both AZ subnets, `min_size = 2`, one instance per AZ at creation, scales from there via a target-tracking policy on CPU utilization. Health check type `ELB`, so unhealthy targets at the load balancer get replaced, not just unhealthy at the instance level.
- Registered to its tier's ALB target group via the ASG's own `target_group_arns`: not a separate attachment resource.

No SSH anywhere. All instance access is via SSM Session Manager. All configuration delivery is via SSM State Manager associations running Ansible playbooks (`ansible/playbooks/base-tasks.yml` + `web-tier.yml`/`app-tier.yml`), pulled from a private, KMS-encrypted S3 bucket and re-applied on a schedule for drift correction (every 7 days): never baked into `user_data`. This same Ansible path now also owns TLS certificate issuance/rotation for the internal hops (see TLS section).

## IAM boundaries

Web and app tiers have separate IAM roles: a compromised web instance never inherits app-tier secret access:

- **Web role**: SSM core policy, read access to the Ansible bundle S3 bucket. Nothing else.
- **App role**: SSM core policy, read access to the Ansible bundle S3 bucket, plus `secretsmanager:GetSecretValue`/`DescribeSecret` scoped to exactly two secrets: the app DB credential and the ElastiCache auth token. Never the RDS master credential, which is break-glass only.

## Data protection

Six purpose-scoped KMS keys, one per service/data class: see `docs/decisions/0001-separate-kms-keys-per-service.md` for rationale.

| Key | Protects |
|---|---|
| `rds` | RDS storage encryption |
| `elasticache` | ElastiCache at-rest encryption |
| `ansible-bundle` | S3 bucket holding Ansible playbooks |
| `secrets` | Secrets Manager (app DB credential, RDS master credential, ElastiCache auth token) |
| `flow-logs` | VPC flow logs CloudWatch log group |
| `ebs` | Root EBS volumes, web/app tier instances |

Each key's policy grants `kms:Decrypt`/`kms:GenerateDataKey` only to the specific AWS service principal that needs it, plus root account access for key administration. **Automatic annual key rotation is enabled on all six keys**: stated explicitly rather than left implicit, per Well-Architected security pillar guidance.

- RDS: `publicly_accessible = false`, `require_secure_transport = ON`, `local_infile` disabled, `storage_encrypted = true` (`rds` key), `deletion_protection = true`. **Automated backups: 7-day retention window** (capstone default: call out explicitly if this needs to change for the demo).
- App-tier RDS database user is least-privilege, created via a standalone SSM-tunneled bootstrap script (`scripts/bootstrap/`), never a Terraform resource with an embedded credential.
- ElastiCache: `transit_encryption_enabled`, `at_rest_encryption_enabled` (`elasticache` key), dedicated auth token in Secrets Manager (`secrets` key).

## Visibility

- VPC Flow Logs (all traffic, ACCEPT+REJECT) → CloudWatch log group, 30-day retention, encrypted under the `flow-logs` key.
- CloudWatch agent is the primary in-instance monitoring path, configured via the Ansible `base-tasks.yml` playbook: not part of the `observability` Terraform module, which owns only the network-level flow log.

## Module map

| Module | Owns |
|---|---|
| `network` | VPC, subnets (public/web/app/db), route tables, NAT gateways, IGW, VPC interface/gateway endpoints, RDS/ElastiCache subnet groups |
| `security` | Security groups (7, including the endpoint SG), IAM roles (web/app), six KMS keys |
| `compute` | Launch templates + ASGs (web/app), Ansible bundle S3 bucket, SSM delivery, Ansible inventory generation |
| `data` | RDS instance, ElastiCache replication group, associated Secrets Manager secrets |
| `edge` | Public/internal ALBs, target groups, CloudFront distribution, WAF Web ACL |
| `observability` | VPC flow logs, flow log IAM role, CloudWatch log group |

Modules never reach into each other's resources directly: every cross-module dependency is an explicit input variable, wired together in `environments/dev/main.tf`. For example: `security` receives `vpc_id = module.network.vpc_id`; `compute` receives `web_subnet_ids`/`app_subnet_ids` from `module.network`.

## Network module detail

**VPC**: one VPC, `10.0.0.0/16` by default (`vpc_cidr` variable). `enable_dns_support = true`, `enable_dns_hostnames = true`.

**Subnets: two AZs, four tiers, one subnet per tier per AZ (8 subnets total)**
- Public: `10.0.0.0/24`, `10.0.1.0/24`: hosts NAT Gateways only, never workload instances.
- Web: `10.0.10.0/24`, `10.0.11.0/24`: private, web-tier ASG.
- App: `10.0.20.0/24`, `10.0.21.0/24`: private, app-tier ASG.
- DB: `10.0.30.0/24`, `10.0.31.0/24`: isolated, RDS + ElastiCache.

**Internet Gateway**: one, attached to the VPC.

**NAT Gateways**: one per AZ (2 total), each in its AZ's public subnet, each with its own EIP. Not a single shared NAT: avoids one NAT Gateway being a cross-AZ dependency for the other AZ's private-tier egress.

**Route tables**
- Public: one table, `0.0.0.0/0 → IGW`, associated with both public subnets.
- Web: one table per AZ, `0.0.0.0/0 → that AZ's NAT Gateway`.
- App: one table per AZ, `0.0.0.0/0 → that AZ's NAT Gateway`.
- DB: one table, **no `0.0.0.0/0` route at all**: only the implicit VPC-local route. This is the actual enforcement mechanism for "data tier has no internet path," not a security group.

**Subnet groups**: `aws_db_subnet_group` and `aws_elasticache_subnet_group`, both spanning the two DB subnets.

**VPC endpoints** (interface, unless noted)
- S3: **gateway** endpoint (free, no ENI), associated with the web/app/db route tables. Lets instances pull the Ansible bundle from S3 without that traffic going out through NAT.
- SSM, SSMMessages, EC2Messages: required for SSM Session Manager / State Manager to function without relying on NAT internet egress for AWS API calls.
- Secrets Manager: lets the app tier retrieve its secrets without that traffic leaving the VPC via NAT.
- Endpoint security group: ingress 443 from the VPC CIDR only, no other source.

**Outputs**: `vpc_id`, `vpc_cidr`, per-tier subnet ID lists (public/web/app/db), `db_subnet_group_name`, `cache_subnet_group_name`.

## Security module detail

Security groups as tabulated above. IAM as specified. KMS: six purpose-scoped keys with annual rotation enabled (ADR 0001).

**Outputs**: all 7 SG IDs, both role ARNs + instance profile names, all 6 KMS key ARNs.

## Compute module detail

As specified above (launch template + ASG per tier, min 2/one-per-AZ, target-tracking on CPU, IMDSv2 enforced, ELB health check type, registered to target group via ASG's `target_group_arns`).

**Additionally owns:**
- Ansible bundle S3 bucket: versioned, encrypted under the `ansible-bundle` key, bucket policy denying non-TLS requests (`aws:SecureTransport` condition).
- Custom SSM document defining the Ansible-apply procedure.
- `aws_ssm_association` per tier, targeted by `tag:Role = web`/`tag:Role = app`, schedule expression re-applying every 7 days.

**Outputs**: launch template IDs, ASG names/ARNs, Ansible bundle bucket ARN + name.

## Data module detail

**RDS**
- `aws_db_parameter_group`, MySQL 8.0 family: forces `require_secure_transport = ON`, disables `local_infile`.
- Master credential: random-generated, stored in Secrets Manager under the `secrets` key. Break-glass only: never referenced by any application IAM policy.
- `aws_db_instance`: MySQL 8.0, `db.t3.micro` default, 20 GiB gp3, `publicly_accessible = false`, `storage_encrypted = true` under the `rds` key, `deletion_protection = true`, 7-day automated backup retention, CloudWatch log exports (audit/error/general/slowquery) enabled, subnet group + SG from network/security module outputs.
- App-tier credential: separate random-generated secret in Secrets Manager (`secrets` key). The actual `CREATE USER`/`GRANT` for this account runs via `scripts/bootstrap/create-app-user.sql` + `bootstrap-app-user.sh`, tunneled through SSM: not a Terraform resource, so the least-privilege grant is never embedded in state.

**ElastiCache**
- `aws_elasticache_replication_group`, Redis 7.1, 2 cache clusters (one per AZ), `cache.t3.micro` default.
- `transit_encryption_enabled = true`, `at_rest_encryption_enabled = true` under the `elasticache` key.
- Auth token: random-generated, stored in Secrets Manager under the `secrets` key.

**Outputs**: RDS endpoint, RDS master secret ARN (break-glass, flagged as such), app DB secret ARN, Redis primary endpoint, ElastiCache auth secret ARN.

## Edge module detail

**Public ALB**: internet-facing, in the two public subnets, `public_alb` SG. Listener on port 80 (see TLS section). Target group forwards to the web tier ASG on `web_listen_port` (8443, TLS).

**Internal ALB**: internal-only, in the two web-tier subnets, `internal_alb` SG. Listener on 443 (TLS). Target group forwards to the app tier ASG on `app_listen_port` (8080, TLS).

**CloudFront**
- Single distribution, default `*.cloudfront.net` certificate (no owned domain).
- Origin: the Public ALB, origin protocol policy HTTP-only (matches the ALB's port-80 listener; see TLS section for rationale).
- WAF Web ACL attached: `AWSManagedRulesCommonRuleSet` + `AWSManagedRulesKnownBadInputsRuleSet`, both count-then-block via managed rule group defaults.

**Outputs**: Public/internal ALB DNS names + ARNs, both target group ARNs, CloudFront domain name, WAF Web ACL ARN.

## Observability module detail

- `aws_flow_log`, `traffic_type = "ALL"`, VPC-wide, destination CloudWatch Logs.
- CloudWatch log group, 30-day retention, encrypted under the `flow-logs` key.
- Dedicated IAM role for the flow-log delivery, no other AWS service.
- CloudWatch agent (primary in-instance monitoring) is configured via the Ansible `base-tasks.yml` playbook, not this module: this module only owns the network-level flow log.

**Outputs**: flow log ID, CloudWatch log group name + ARN.

## Related documents

- `docs/decisions/0001-separate-kms-keys-per-service.md`
- `docs/architecture/trust-boundaries.md`
- `docs/architecture/threat-model.md`
- `docs/architecture/dfd.md`
- `docs/security/iam-strategy.md`
- `docs/security/network-security.md`
- `docs/security/data-protection.md`


```text
cloud-security-capstones/
│
├── README.md
│
├── aws/
│   └── capstone-security/
│       │
│       ├── infrastructure/
│       │   │
│       │   ├── modules/
│       │   │   │
│       │   │   ├── network/
│       │   │   │   ├── vpc.tf
│       │   │   │   ├── vpc_endpoints.tf
│       │   │   │   ├── variables.tf
│       │   │   │   └── outputs.tf
│       │   │   │
│       │   │   ├── security/
│       │   │   │   ├── security_groups.tf
│       │   │   │   ├── iam.tf
│       │   │   │   ├── kms.tf
│       │   │   │   ├── variables.tf
│       │   │   │   └── outputs.tf
│       │   │   │
│       │   │   ├── compute/
│       │   │   │   ├── compute.tf
│       │   │   │   ├── ansible.tf
│       │   │   │   ├── variables.tf
│       │   │   │   └── outputs.tf
│       │   │   │
│       │   │   ├── data/
│       │   │   │   ├── rds.tf
│       │   │   │   ├── elasticache.tf
│       │   │   │   ├── variables.tf
│       │   │   │   └── outputs.tf
│       │   │   │
│       │   │   ├── edge/
│       │   │   │   ├── cloudfront_waf.tf
│       │   │   │   ├── alb.tf
│       │   │   │   ├── variables.tf
│       │   │   │   └── outputs.tf
│       │   │   │
│       │   │   └── observability/
│       │   │       ├── observability.tf
│       │   │       ├── variables.tf
│       │   │       └── outputs.tf
│       │   │
│       │   └── environments/
│       │       └── dev/
│       │           ├── main.tf
│       │           ├── variables.tf
│       │           ├── terraform.tfvars
│       │           ├── outputs.tf
│       │           ├── versions.tf
│       │           └── backend.tf
│       │
│       ├── ansible/
│       │   ├── inventory/
│       │   ├── playbooks/
│       │   │   ├── README.md
│       │   │   ├── base-tasks.yml
│       │   │   ├── web-tier.yml
│       │   │   └── app-tier.yml
│       │   ├── roles/
│       │   ├── group_vars/
│       │   └── host_vars/
│       │
│       ├── scripts/
│       │   ├── bootstrap/
│       │   │   ├── bootstrap-app-user.sh
│       │   │   └── create-app-user.sql
│       │   ├── security-tests/
│       │   └── validation/
│       │       ├── aws-port-exposure-check.sh
│       │       ├── aws-port-exposure-check.py
│       │       ├── aws-imdsv2-check.sh
│       │       ├── aws-imdsv2-check.py
│       │       ├── aws-tls-enforcement-check.sh
│       │       └── aws-tls-enforcement-check.py
│       │
│       ├── tests/
│       │   ├── terraform/
│       │   ├── security/
│       │   └── integration/
│       │
│       ├── evidence/
│       │   ├── architecture/
│       │   ├── terraform/
│       │   ├── ansible/
│       │   ├── validation/
│       │   └── findings/
│       │
│       ├── docs/
│       │   ├── architecture/
│       │   │   ├── dfd.md
│       │   │   ├── trust-boundaries.md
│       │   │   ├── architecture-overview.md
│       │   │   └── threat-model.md
│       │   ├── security/
│       │   │   ├── network-security.md
│       │   │   ├── secrets-management.md
│       │   │   ├── hardening-checklist.md
│       │   │   ├── data-protection.md
│       │   │   ├── iam-strategy.md
│       │   │   └── security-controls.md
│       │   ├── operations/
│       │   ├── validation/
│       │   │   └── validation-guide.md
│       │   └── decisions/
│       │
│       ├── diagrams/
│       │   ├── az-placement.svg
│       │   ├── request-path.svg
│       │   └── dfd.svg
│       │
│       ├── .github/
│       │   └── workflows/
│       │
│       └── README.md
│
├── azure/
│   └── capstone-security/
│       ├── infrastructure/
│       ├── automation/
│       ├── scripts/
│       ├── tests/
│       ├── evidence/
│       ├── docs/
│       ├── diagrams/
│       └── README.md
│
├── gcp/
│   └── capstone-security/
│       ├── infrastructure/
│       ├── automation/
│       ├── scripts/
│       ├── tests/
│       ├── evidence/
│       ├── docs/
│       ├── diagrams/
│       └── README.md
│
└── shared/
    ├── security-baseline/
    │   └── README.md
    ├── documentation/
    │   └── README.md
    └── templates/
        └── README.md
```
