# Validation Guide — capstone

Every claim in `docs/security/hardening-checklist.md` has a check
here. Evidence (command output, screenshot) should attach to an
`evidence/validation/` folder, named to match the check.

| # | Claim | How to validate | Evidence |
|---|---|---|---|
| 1 | SSM-only, no SSH | ssh -v <instance-ip> from outside -> connection refused/timeout | 01-ssh-refused.png |
| 2 | ufw default deny incoming | sudo ufw status verbose via SSM Session Manager | 02-ufw-status.txt |
| 3 | IMDSv2 enforced | scripts/validation/aws-imdsv2-check.py | 03-imdsv2-check.txt |
| 4 | Web tier: only 80/443 from ALB | scripts/validation/aws-port-exposure-check.py | 04-web-port-exposure.txt |
| 5 | App tier: port only from internal ALB | Same script, targeted at app tier | 05-app-port-exposure.txt |
| 6 | Non-root service users | ps -eo user,cmd on instance shows webapp/appsvc, not root | 06-process-owner.txt |
| 7 | RDS not publicly accessible | scripts/validation/aws-tls-enforcement-check.py | 07-rds-public-check.txt |
| 8 | RDS TLS enforced | Same script; plaintext mysql connection attempt rejected | 08-rds-tls-rejection.txt |
| 9 | ElastiCache TLS enforced | redis-cli connection attempt without --tls -> rejected | 09-elasticache-tls-rejection.txt |
| 10 | app_svc least privilege | SHOW GRANTS FOR 'app_svc'@'<app-subnet-cidr>'; | 10-app-svc-grants.txt |
| 11 | Secrets not hardcoded | git log -p search, or trust .gitleaks.toml CI history | 11-gitleaks-history.txt |
| 12 | SSM association compliance | aws ssm describe-association --association-id <id> | 12-ssm-association-status.txt |
| 13 | CloudWatch agent running/shipping | CloudWatch console — log groups show recent entries | 13-cloudwatch-logs.png |
| 14 | KMS encryption at rest | aws kms describe-key + resource Encrypted fields | 14-kms-encryption-check.txt |
| 15 | Patch compliance | SSM Patch Manager compliance report | 15-patch-compliance.png |

## Not yet validated

- DNS resolution unaffected by ufw (planned quick check: dig from an
  instance post-hardening)
- Wazuh agent path — deferred until CloudWatch path is fully validated
