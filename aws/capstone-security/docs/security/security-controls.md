# Security Controls Inventory

Full control list, organized by category. Cross-referenced to where
each is implemented and how it's validated.

## Edge & Network

| Control | Implementation | Validated by |
|---|---|---|
| TLS termination | CloudFront default cert | Manual cert inspection |
| WAF filtering | WAF attached to CloudFront distribution | WAF managed rule metrics |
| DDoS protection | Shield Standard (automatic w/ CloudFront) | N/A — always-on |
| Tiered subnet isolation | 4 subnet tiers x 2 AZs, SG-to-SG trust chain | aws-port-exposure-check.py |
| No public DB/cache access | RDS/ElastiCache PubliclyAccessible=false | aws-tls-enforcement-check.py |

## Identity

| Control | Implementation | Validated by |
|---|---|---|
| No SSH/bastion | SSM Session Manager only | Manual SSH-refused test |
| Per-tier IAM roles | Separate roles for web/app, least privilege | Manual policy review |
| No long-lived instance credentials | Instance profiles only | .gitleaks.toml CI scan |

## Host

| Control | Implementation | Validated by |
|---|---|---|
| Password auth disabled | Ansible base-hardening role | SSM config check |
| Root login disabled | Ansible base-hardening role | Same |
| Host firewall (default-deny) | ufw via Ansible | ufw status via SSM |
| IMDSv2 enforced | Launch template metadata_options | aws-imdsv2-check.py |
| File integrity monitoring | AIDE | Manual aide --check review |
| Patch compliance | SSM Patch Manager | SSM compliance report |

## Data

| Control | Implementation | Validated by |
|---|---|---|
| Encryption at rest | KMS-backed | aws-tls-enforcement-check.py |
| Encryption in transit (RDS) | require_secure_transport=ON | aws-tls-enforcement-check.py |
| Encryption in transit (ElastiCache) | transit_encryption_enabled=true | aws-tls-enforcement-check.py |
| Least-privilege DB credential | app_svc, scoped grants + host CIDR | Manual SHOW GRANTS check |
| Secrets never hardcoded | Secrets Manager for all credentials | .gitleaks.toml CI scan |

## Detection

| Control | Implementation | Validated by |
|---|---|---|
| API activity logging | CloudTrail | Log review |
| Network flow logging | VPC Flow Logs | Log review |
| Threat detection | GuardDuty | Finding review |
| Compliance posture | Security Hub (CIS AWS Foundations) | Standard score |
| Config drift detection | AWS Config | Rule compliance review |
| Instance-level monitoring | CloudWatch agent | Log group review |

## Status

Every implementation above reflects what has been designed. Treat as
claims to verify against the live environment, not confirmed facts,
until validated per `docs/validation/validation-guide.md`.
