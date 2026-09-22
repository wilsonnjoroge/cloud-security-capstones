# IAM Strategy: AWS Capstone

## Purpose

This document is the single source of truth for identity and access design across the capstone: every IAM role, what it can do, what it explicitly cannot do, and why.

`docs/architecture/trust-boundaries.md` and `docs/architecture/threat-model.md` reference this document at the relevant trust boundaries. This document provides the detailed IAM policy model behind those architectural summaries.

**Governing principle:** every role is scoped to the minimum permission set its tier needs to function, verified negatively as much as positively. This document therefore states not only what each role can do, but explicitly what it cannot do.

---

## Role inventory

| Role                | Attached to                                   | Core purpose                                                                 |
| ------------------- | --------------------------------------------- | ---------------------------------------------------------------------------- |
| `web`               | Web-tier launch template via instance profile | SSM management + Ansible bundle retrieval                                    |
| `app`               | App-tier launch template via instance profile | SSM management + Ansible bundle retrieval + two scoped Secrets Manager reads |
| `flow-log-delivery` | VPC Flow Logs → CloudWatch Logs delivery      | Deliver VPC Flow Logs to CloudWatch Logs                                     |
| *(break-glass)*     | Human operator, not an instance role          | RDS master credential access                                                 |

No shared application role exists across the web and app tiers.

The web and app roles are deliberately separate. This separation is an IAM control that complements the network trust chain established in `trust-boundaries.md` and `network-security.md`.

There is deliberately no bastion-host role, SSH administration role, or shared "app-tier" instance role.

---

## Web role

**Attached to:** web-tier launch template via instance profile.

### Permissions

#### 1. SSM management

* `AmazonSSMManagedInstanceCore`: AWS-managed baseline required for SSM managed-instance functionality and Session Manager / State Manager operation.
* This is the approved remote-management mechanism for the tier.
* There is no SSH key, bastion host, or alternative administrative access path.

#### 2. Ansible bundle retrieval

The role receives:

* `s3:GetObject`

scoped only to the Ansible bundle objects required by the instance.

The resource scope is the object path:

```text
arn:aws:s3:::<ansible-bundle-bucket>/*
```

The role does **not** receive:

* `s3:PutObject`
* `s3:DeleteObject`
* `s3:PutBucketPolicy`
* `s3:DeleteBucket`
* broad S3 administration
* unnecessary `s3:ListAllMyBuckets`

` s3:ListBucket` is not required when the State Manager/Ansible workflow retrieves known object keys directly.

### Explicitly does not have

* Any `secretsmanager:*` permission.
* Access to the application DB credential.
* Access to the Redis AUTH token.
* Access to the RDS master credential.
* RDS permissions.
* ElastiCache permissions.
* Application-specific KMS permissions.
* EBS KMS permissions.
* Permissions referencing app-tier resources.
* Permissions referencing app-tier security groups or Auto Scaling resources.

The web instance role therefore has no IAM path to application credentials or data.

### Why this matters

A compromised web instance inherits the permissions of this role.

Its IAM authority is intentionally limited to:

1. SSM-managed-instance operation.
2. Retrieval of the Ansible configuration bundle.

It cannot use IAM permissions to retrieve the application database credential, Redis AUTH token, or RDS master credential.

This IAM restriction complements the network boundary that prevents the web tier from directly reaching the application tier's protected data services.

---

## App role

**Attached to:** app-tier launch template via instance profile.

### Permissions

#### 1. SSM management

* `AmazonSSMManagedInstanceCore`: AWS-managed baseline required for SSM managed-instance functionality and Session Manager / State Manager operation.

#### 2. Ansible bundle retrieval

* `s3:GetObject`

scoped to the Ansible bundle object path:

```text
arn:aws:s3:::<ansible-bundle-bucket>/*
```

No S3 write or bucket-administration permissions are granted.

#### 3. Secrets Manager reads

The app role receives:

* `secretsmanager:GetSecretValue`
* `secretsmanager:DescribeSecret`

scoped to exactly two secret ARNs:

1. The application DB credential containing the `app_svc` account credential.
2. The ElastiCache Redis AUTH token.

These are named-resource permissions.

The policy does **not** use a wildcard such as:

```text
arn:aws:secretsmanager:*:*:secret:*
```

because that would allow the application tier to retrieve unrelated secrets.

### Explicitly does not have

* Access to the RDS master credential secret.
* `secretsmanager:PutSecretValue`.
* `secretsmanager:DeleteSecret`.
* Broad Secrets Manager administration.
* RDS administration permissions.
* ElastiCache administration permissions.
* Permissions referencing web-tier resources.
* Permissions referencing unrelated application secrets.
* Direct IAM permissions for decrypting the RDS, ElastiCache, or EBS KMS keys.

### Why this matters

A fully compromised app instance can obtain only the two application credentials required for its function:

* the least-privilege `app_svc` database credential;
* the Redis AUTH token.

It cannot retrieve the RDS master credential.

The app role's access to those two secrets does not grant it access to arbitrary Secrets Manager resources.

---

## The RDS master credential: break-glass only

The RDS master credential is stored in Secrets Manager using the dedicated `secrets` KMS key.

No compute IAM role references the RDS master secret ARN.

Access is intended to be:

* **Manual:** retrieved by an appropriately authorized human operator when genuinely required.
* **Break-glass:** used for initial database bootstrap, emergency recovery, or equivalent administrative operations.
* **Never application-facing:** no application instance role can retrieve it.
* **Never embedded in Ansible:** the master credential is not placed in playbooks or configuration bundles.
* **Never stored as plaintext in Terraform configuration or state.**

Terraform manages the secret resource and its lifecycle without exposing the master credential as a plaintext Terraform configuration value.

The application instead uses the separate least-privilege `app_svc` database account.

This separation is deliberate: the most powerful database credential is excluded from all automated application paths rather than merely being given a more restrictive application permission.

---

## Flow-log delivery role

**Attached to:** the VPC Flow Logs → CloudWatch Logs delivery configuration.

This is a dedicated service role and is not an EC2 instance profile.

### Permissions

The role is scoped to the CloudWatch Logs resources required for VPC Flow Log delivery, including the permissions required to:

* create the log group where required;
* create log streams;
* put log events;
* describe the relevant log groups and streams.

The resources are restricted to the dedicated VPC Flow Logs CloudWatch Logs group rather than broad CloudWatch Logs administration.

### Why a dedicated role

Flow-log delivery is a separate infrastructure trust boundary from application compute.

It therefore does not share the web or app instance roles.

A problem with flow-log delivery cannot automatically inherit the application permissions associated with the web or app instance profiles.

---

## KMS and IAM: how they interact

The architecture uses six purpose-scoped customer-managed KMS keys:

1. `rds`
2. `elasticache`
3. `ansible-bundle`
4. `secrets`
5. `flow-logs`
6. `ebs`

Each key has a dedicated purpose and appropriate service-oriented key policy.

KMS permissions are deliberately separated from application IAM permissions.

### Secrets Manager example

For the application DB credential:

1. The **app IAM role** is authorized to call `secretsmanager:GetSecretValue` for the specific DB secret ARN.
2. **Secrets Manager** uses the dedicated `secrets` KMS key to decrypt the encrypted secret value.
3. The plaintext secret value is returned to the authorized application session.

The app IAM role therefore does not receive broad direct access to the `secrets` KMS key simply because it is allowed to retrieve a specific secret.

The same principle applies to the other service-specific KMS keys.

### Key separation

The six KMS keys are not interchangeable.

The:

* RDS key protects RDS encryption.
* ElastiCache key protects ElastiCache encryption at rest.
* Ansible-bundle key protects the Ansible artifact store.
* Secrets key protects Secrets Manager secrets.
* Flow-logs key protects the CloudWatch Logs destination used for VPC Flow Logs.
* EBS key protects encrypted EBS volumes.

Annual rotation is enabled for all six keys.

Root account access remains available for key administration and recovery in accordance with the approved key-management design.

---

## IMDSv2: IAM-adjacent control

IMDSv2 is configured at the launch-template level:

```text
http_tokens = "required"
http_put_response_hop_limit = 1
```

IMDSv2 is not an IAM permission.

It is included here because it protects the temporary credentials associated with the instance IAM role.

The controls therefore provide two complementary layers:

* **IAM least privilege** limits what stolen temporary credentials can do.
* **IMDSv2 enforcement** makes credential theft through common metadata-based SSRF paths substantially harder.

Neither control substitutes for the other.

---

## IAM trust model

The resulting identity model is:

```text
                        AWS IAM
                           |
             +-------------+-------------+
             |                           |
         Web Role                    App Role
             |                           |
      +------+------+          +---------+---------+
      |             |          |         |         |
     SSM          S3 Get     SSM       S3 Get   Secrets
      |             |          |         |         |
      |             |          |         |     +---+---+
      |             |          |         |     |       |
      |             |          |         |    DB      Redis
      |             |          |         |   Secret   Secret
      |             |          |         |     |       |
      |             |          |         |     +---+---+
      |             |          |         |         |
      +-------------+          +---------+---------+
```

The RDS master secret is intentionally outside both automated instance-role paths:

```text
Human break-glass operator
          |
          v
RDS master secret
```

No application instance role has access to this secret.

---

## Negative authorization model

Least privilege must be demonstrated through negative testing, not inferred solely from policy files.

The validation plan must establish that:

### Web role cannot

* retrieve the app DB secret;
* retrieve the Redis AUTH secret;
* retrieve the RDS master secret;
* perform RDS administration;
* perform ElastiCache administration;
* decrypt unrelated customer-managed KMS keys.

### App role can

* retrieve the designated app DB secret;
* retrieve the designated Redis AUTH secret;
* retrieve the Ansible bundle;
* operate through SSM.

### App role cannot

* retrieve the RDS master secret;
* retrieve unrelated Secrets Manager secrets;
* modify or delete the application secrets;
* perform RDS administration;
* perform ElastiCache administration;
* access web-tier-only resources through IAM.

### Evidence requirement

Policy documents alone do not constitute validation.

The permission boundaries above remain **Planned** until Terraform is implemented.

They become **Implemented** once deployed.

They become **Validated** only when live tests produce evidence under:

```text
evidence/validation/
```

The evidence should include successful positive tests and expected `AccessDenied` results for the negative tests.

---

## Cross-references: where this document's claims are used

| IAM claim                                  | Referenced by                                                        |
| ------------------------------------------ | -------------------------------------------------------------------- |
| Web/app role separation                    | `trust-boundaries.md` boundary 6; `threat-model.md` boundaries 3/6/7 |
| Web role cannot access application secrets | `trust-boundaries.md`; `threat-model.md`                             |
| App role's two-secret scope                | `trust-boundaries.md` boundary 6; `network-security.md`              |
| RDS master credential break-glass model    | `architecture-overview.md`; `trust-boundaries.md` boundary 6         |
| SSM-only administration                    | `architecture-overview.md`; `network-security.md`; `threat-model.md` |
| IMDSv2 rationale                           | `threat-model.md` cross-cutting threats                              |
| Six purpose-specific KMS keys              | `architecture-overview.md`; `data-protection.md`                     |
| Negative IAM validation                    | `scripts/validation/`; `evidence/validation/`                        |

---

## Status model

Consistent with the rest of the capstone documentation:

**Planned**

The IAM design exists in documentation but the corresponding Terraform has not yet been deployed.

**Implemented**

The IAM resources and policies have been deployed through:

```text
infrastructure/modules/security/
```

and the deployed configuration matches this document.

**Validated**

Live tests have demonstrated that the deployed permissions behave as designed, with evidence stored under:

```text
evidence/validation/
```

In particular, validation must demonstrate both:

* the web role cannot retrieve application secrets;
* the app role can retrieve its two designated secrets;
* the app role cannot retrieve the RDS master credential.

Configuration files and policy documents alone are not validation evidence.

---

## Related documents

* `docs/architecture/architecture-overview.md`: overall architecture and IAM boundaries
* `docs/architecture/trust-boundaries.md`: per-boundary control detail
* `docs/architecture/threat-model.md`: threats involving identity and credential compromise
* `docs/security/network-security.md`: network controls that complement IAM
* `docs/security/data-protection.md`: encryption and KMS controls
* `docs/decisions/0001-separate-kms-keys-per-service.md`: rationale for six purpose-specific KMS keys
* `scripts/validation/`: live IAM and security validation tooling
* `evidence/validation/`: evidence supporting validated security claims
