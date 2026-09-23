# multicloud-terraform-security — capstone

Cloud security capstone: a 3-tier AWS web application built to
demonstrate defense-in-depth across edge, network, identity, host,
and data layers, for a fictional fintech persona. AWS is the current
focus; Azure and GCP are planned as siblings under the same repo.

## Structure

- `infrastructure/environments/capstone/` — Terraform for the 3-tier
  architecture: CloudFront + WAF, public/internal ALBs, web/app
  Auto Scaling Groups, RDS + ElastiCache
- `ansible/playbooks/` — hardening playbooks delivered via SSM State
  Manager associations (no SSH, no bastion)
- `scripts/validation/` — AWS API–based checks proving hardening
  claims are actually true, paired `.py`/`.sh`
- `scripts/db-bootstrap/` — least-privilege `app_svc` MySQL user
  creation, tunneled through SSM
- `diagrams/` — architecture and data-flow diagram sources
- `docs/architecture/` — overview, threat model, trust boundaries, DFD
- `docs/security/` — control inventory, hardening checklist, IAM,
  network, data, and secrets strategy documents
- `docs/validation/` — validation guide (claim → check → evidence)

## Status

This package is a design and build artifact produced collaboratively
across a working session. Every document is written honestly about
what is designed versus what has been confirmed against a live,
deployed environment — look for "Status" and "Verification items"
sections in each doc rather than assuming a claim is proven.

## Security posture summary

| Layer | Controls |
|---|---|
| Edge | CloudFront (TLS termination) + WAF, Shield Standard |
| Network | Tiered VPC (public/web/app/DB subnets), SG-to-SG trust chain, NACLs |
| Identity | Per-tier IAM roles, least privilege, no long-lived keys |
| Data | KMS encryption at rest, TLS enforced in transit |
| Host | SSM-only access, host firewall, non-root process users, Patch Manager |
| Detection | GuardDuty, Security Hub, AWS Config, CloudTrail, VPC Flow Logs |

Full detail on each layer lives in `docs/security/`. Documented
tradeoffs (scope exclusions, accepted simplifications) are named
explicitly in `docs/architecture/architecture-overview.md` rather
than left silent.

## Getting started

```bash
cd infrastructure/environments/capstone
terraform init
terraform plan
```

## Validation

Every hardening claim in `docs/security/hardening-checklist.md` has a
corresponding check in `scripts/validation/` and a proof entry in
`docs/validation/validation-guide.md`.
