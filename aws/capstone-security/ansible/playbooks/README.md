# Ansible Playbooks — scope note

This architecture has three tiers: web, app, and db — same as any
other 3-tier design. Only two of them have playbooks here.

## Why there's no db-tier.yml

Web and app are EC2 instances with a real operating system Ansible
can reach via SSM. The db tier is RDS (MySQL) + ElastiCache (Redis) —
AWS-managed services with no OS to reach. There's nothing for a
playbook to configure; "hardening" the db tier means Terraform
resource arguments instead (`require_secure_transport`,
`storage_encrypted`, `transit_encryption_enabled`, parameter groups —
see `infrastructure/environments/capstone/data.tf`).

This is a deliberate architectural difference, not a missing file.
All three tiers are still tagged consistently for visibility in the
AWS console and for queries against CloudTrail/Config:

| Tier | Tag | Hardening mechanism |
|---|---|---|
| Web | `Role=web` (drives SSM targeting), `Tier=web` | `base-tasks.yml` + `web-tier.yml` |
| App | `Role=app` (drives SSM targeting), `Tier=app` | `base-tasks.yml` + `app-tier.yml` |
| DB | `Tier=db` (no `Role` tag — not an SSM-managed instance) | Terraform config in `data.tf` |

See `docs/architecture/architecture-overview.md` ("Data tier
distinction") and `docs/security/hardening-checklist.md` for the
full explanation.

## Files in this folder

- `base-tasks.yml` — shared hardening tasks (SSH lockdown, ufw,
  CloudWatch agent, aide), included by both tier playbooks below,
  not run directly
- `web-tier.yml` — base tasks + web-tier-specific rules (80/443 from
  the public ALB only, non-root `webapp` service user)
- `app-tier.yml` — base tasks + app-tier-specific rules (app port
  from the internal ALB only, non-root `appsvc` service user)
