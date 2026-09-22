# Data Protection: AWS Capstone

## Purpose

This document defines how data is classified, protected at rest and in transit, accessed using least privilege, retained, and verified across the AWS capstone environment.

The design is intentionally aligned with the approved architecture, trust boundaries, network security, IAM strategy, and threat model.

---

## Data classification

All application data in this environment is **synthetic and Faker-generated**.

The environment must never contain real customer data, production credentials, or real personal information.

The synthetic-data design reduces the impact of a potential compromise because the capstone does not contain real customer or personal data.

Synthetic data must nevertheless be treated as protected application data so that the security controls demonstrate how a production environment would protect sensitive information.

The seed process must generate synthetic records without importing or copying real customer datasets.

---

## Encryption at rest

All supported persistent data stores and security-sensitive artifacts use encryption at rest.

| Resource                        | Protection                                                                            |
| ------------------------------- | ------------------------------------------------------------------------------------- |
| RDS MySQL                       | `storage_encrypted = true`, dedicated customer-managed `rds` KMS key                  |
| ElastiCache Redis               | `at_rest_encryption_enabled = true`, dedicated customer-managed `elasticache` KMS key |
| Ansible bundle S3 bucket        | SSE-KMS using the dedicated `ansible-bundle` KMS key                                  |
| Secrets Manager secrets         | Customer-managed `secrets` KMS key                                                    |
| VPC Flow Logs / CloudWatch Logs | Customer-managed `flow-logs` KMS key                                                  |
| Web/App EBS volumes             | KMS encryption using the dedicated `ebs` KMS key                                      |

The six KMS keys are purpose-specific:

1. `rds`
2. `elasticache`
3. `ansible-bundle`
4. `secrets`
5. `flow-logs`
6. `ebs`

The keys are deliberately separated rather than using one shared encryption key across all services.

Annual key rotation is enabled.

Application IAM roles do not receive broad direct KMS permissions simply because they consume encrypted services. Service-specific encryption and decryption paths are governed through the applicable AWS service and KMS key policy.

---

## Encryption in transit

| Path                                | Protection                                                          |
| ----------------------------------- | ------------------------------------------------------------------- |
| Client → CloudFront                 | HTTPS/TLS using CloudFront's default `*.cloudfront.net` certificate |
| CloudFront → Public ALB             | HTTP/80: deliberate documented architectural exception             |
| Public ALB → Web tier               | HTTPS/8443                                                          |
| Web tier → Internal ALB             | HTTPS/443                                                           |
| Internal ALB → App tier             | HTTPS/8080                                                          |
| App tier → RDS                      | TLS required through RDS `require_secure_transport = ON`            |
| App tier → ElastiCache              | TLS with transit encryption enabled                                 |
| App tier → Secrets Manager          | TLS through the AWS API                                             |
| Instances → AWS management/services | TLS through AWS service APIs                                        |

### CloudFront → Public ALB exception

CloudFront-to-origin traffic is intentionally HTTP in this capstone.

This is an accepted architectural limitation because the environment does not currently use an owned public domain with a publicly trusted ACM certificate suitable for the origin.

The client-facing connection remains HTTPS.

The production remediation is:

1. Use an owned domain.
2. Provision a publicly trusted ACM certificate.
3. Configure the ALB for HTTPS.
4. Configure CloudFront to use HTTPS-only origin communication.
5. Remove the HTTP origin dependency.

This exception must remain explicitly documented rather than being silently treated as a security control.

---

## RDS data protection

RDS MySQL is deployed privately and is not publicly accessible.

Required controls include:

* `publicly_accessible = false`
* storage encryption enabled;
* dedicated RDS KMS key;
* automated backups retained for **7 days**;
* deletion protection enabled;
* TLS required through `require_secure_transport = ON`;
* application database access through the dedicated `app_svc` account;
* RDS master credential excluded from application IAM access;
* CloudWatch log exports enabled for the applicable RDS logs.

The database subnets have no default internet route.

The application reaches RDS through the approved security-group relationship on TCP/3306.

---

## ElastiCache data protection

Redis is deployed privately and is accessible only from the application tier through the approved security-group relationship.

Required controls include:

* Redis 7.1 target;
* transit encryption enabled;
* encryption at rest enabled;
* dedicated `elasticache` KMS key;
* Redis AUTH token stored in Secrets Manager;
* application retrieval of the AUTH token limited to the app IAM role;
* two cache clusters distributed across the two availability zones.

The web tier has no security-group-authorized path to Redis.

---

## Secrets protection

Application secrets are stored in AWS Secrets Manager.

The application IAM role can retrieve exactly two secrets:

1. The `app_svc` database credential.
2. The Redis AUTH token.

The application role cannot retrieve the RDS master credential.

The RDS master credential is a break-glass credential intended for authorized human operators only.

Secrets are encrypted using the dedicated `secrets` KMS key.

Secrets must not be placed in:

* Terraform source files;
* Terraform variables committed to Git;
* Terraform state as plaintext values;
* Ansible playbooks;
* AMIs;
* application source code;
* GitHub repository files.

---

## Least-privilege data access

The application connects to RDS using the dedicated:

```text
app_svc
```

database account.

The account is limited to the application's required database/schema operations and is not the RDS master account.

The database account is an additional authorization layer beyond the network security group.

The controls therefore operate at multiple levels:

```text
Application
    |
    v
App IAM role
    |
    +--> Secrets Manager
    |       |
    |       v
    |    app_svc credential
    |
    v
Network SG
    |
    v
RDS
    |
    v
MySQL authorization
    |
    v
Application schema
```

The MySQL account's permitted source host/address scope should correspond to the application tier's actual source addresses or host patterns.

This database-level restriction is complementary to, not a replacement for, the RDS security group.

The application must never require the RDS master credential during normal operation.

---

## Ansible bundle protection

The Ansible configuration bundle is stored in the dedicated S3 bucket.

Protection includes:

* SSE-KMS using the `ansible-bundle` KMS key;
* S3 versioning;
* TLS-only bucket access;
* instance-role read-only access;
* no application-instance write permission;
* retrieval through the approved SSM State Manager workflow.

The web and app instance roles receive only the S3 object permissions required to retrieve the bundle.

The Ansible bundle is therefore protected both as stored data and through IAM-controlled access.

Encryption and versioning do not by themselves prove artifact authenticity. Any future supply-chain integrity mechanism must be separately implemented and validated.

---

## EBS protection

Web and app instance EBS volumes are encrypted.

The encryption uses the dedicated `ebs` customer-managed KMS key.

The EC2 instance roles do not receive broad `kms:Decrypt` permissions for the EBS key merely because their attached volumes are encrypted.

Encryption is handled through the AWS EBS/EC2 service encryption path.

EBS encryption therefore protects persistent instance storage without expanding the application IAM roles with unnecessary KMS authority.

---

## VPC Flow Logs and log protection

VPC Flow Logs capture all traffic under the approved network-security design.

The logs are delivered to CloudWatch Logs and protected using:

* the dedicated `flow-logs` KMS key;
* **30-day retention** for the VPC Flow Logs log group;
* the dedicated flow-log delivery IAM role.

Log retention for other CloudWatch log groups must be explicitly configured rather than relying on indefinite retention.

The exact retention period may differ by log type where justified, but it must be intentional and documented.

---

## Data retention and lifecycle

| Data                    | Retention / lifecycle                                                                    |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| RDS automated backups   | **7 days**                                                                               |
| VPC Flow Logs           | **30 days**                                                                              |
| Other CloudWatch Logs   | Explicitly configured per log group                                                      |
| Ansible S3 objects      | Versioned; lifecycle policy to be explicitly defined                                     |
| Secrets Manager secrets | Retained according to secret lifecycle; deletion/recovery behavior explicitly configured |
| EBS snapshots           | Created only where required for operations/forensics; lifecycle to be explicitly defined |

Retention settings are security controls and must not be left to undocumented AWS defaults.

---

## Data access boundaries

The approved data-access model is:

```text
Internet
   |
   v
CloudFront
   |
   v
Public ALB
   |
   v
Web tier
   |
   v
Internal ALB
   |
   v
App tier
   |
   +------> RDS MySQL
   |
   +------> ElastiCache Redis
   |
   +------> Secrets Manager
```

The web tier does not have IAM permission to retrieve application secrets.

The web tier also does not have a security-group-authorized path to RDS or Redis.

The app tier can access only the application secrets required for normal operation.

The RDS master credential remains outside the automated application path.

---

## Verification items

The following controls must be verified during implementation and validation:

* [ ] Confirm all six KMS keys exist and are purpose-specific.
* [ ] Confirm KMS key policies do not grant unnecessary broad `kms:*` access.
* [ ] Confirm RDS uses the dedicated `rds` KMS key.
* [ ] Confirm ElastiCache uses the dedicated `elasticache` KMS key.
* [ ] Confirm S3 Ansible artifacts use the dedicated `ansible-bundle` KMS key.
* [ ] Confirm Secrets Manager uses the dedicated `secrets` KMS key.
* [ ] Confirm VPC Flow Logs use the dedicated `flow-logs` KMS key.
* [ ] Confirm EBS encryption uses the dedicated `ebs` KMS key.
* [ ] Confirm RDS automated backup retention is exactly 7 days.
* [ ] Confirm VPC Flow Logs retention is exactly 30 days.
* [ ] Confirm other CloudWatch log groups have explicit retention settings.
* [ ] Confirm RDS `publicly_accessible = false`.
* [ ] Confirm RDS `require_secure_transport = ON`.
* [ ] Confirm ElastiCache transit encryption is enabled.
* [ ] Confirm ElastiCache at-rest encryption is enabled.
* [ ] Confirm the web IAM role cannot retrieve application secrets.
* [ ] Confirm the app IAM role can retrieve only the two designated secrets.
* [ ] Confirm the app IAM role cannot retrieve the RDS master credential.
* [ ] Confirm `app_svc` is not the RDS master account.
* [ ] Confirm database authorization is restricted to the application's required schema operations.
* [ ] Confirm the synthetic-data seed process contains no real customer or personal data.
* [ ] Confirm the seed process does not source production datasets.
* [ ] Confirm encryption controls are validated against the deployed environment rather than only Terraform configuration.

---

## Status model

As with the other capstone documents:

**Planned**

The control is documented but has not yet been deployed.

**Implemented**

The control exists in the deployed AWS environment and corresponds to the Terraform/Ansible configuration.

**Validated**

Live evidence demonstrates that the deployed control behaves as intended.

Evidence must be stored under:

```text
evidence/validation/
```

A Terraform configuration stating `storage_encrypted = true`, for example, is implementation evidence, not proof that the deployed resource was actually created with the expected encryption configuration.

---

## Related documents

* `docs/architecture/architecture-overview.md`: overall architecture and data-protection requirements
* `docs/architecture/trust-boundaries.md`: data-flow and trust-boundary controls
* `docs/architecture/threat-model.md`: data-related threats and residual risks
* `docs/security/network-security.md`: network controls protecting data paths
* `docs/security/iam-strategy.md`: identity and least-privilege controls
* `docs/decisions/0001-separate-kms-keys-per-service.md`: rationale for purpose-specific KMS keys
* `scripts/provisioning/`: synthetic-data provisioning
* `scripts/validation/`: security and data-protection validation
* `evidence/validation/`: live validation evidence
