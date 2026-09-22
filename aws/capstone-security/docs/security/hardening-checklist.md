# Server Hardening Checklist: AWS Capstone

Each hardening control must have a corresponding implementation or validation mechanism.

The checklist is divided between:

* EC2 operating-system hardening delivered through Ansible and SSM;
* Terraform-level hardening of AWS-managed services;
* delivery and configuration-integrity controls.

A checked configuration item is not, by itself, evidence that the deployed control has been validated.

---

## Scope note

The web and app tiers are EC2 instances. OS-level hardening is therefore applied through Ansible and delivered through AWS Systems Manager State Manager.

There is:

* no SSH administration path;
* no SSH key provisioned for administrative access;
* no bastion host.

SSM Session Manager is the approved administrative mechanism.

The RDS and ElastiCache tiers are AWS-managed services. There is no customer-managed operating system to harden. Their security posture is therefore established through Terraform resource configuration, IAM, networking, encryption, authentication, and service-level controls.

This is a deliberate architectural difference rather than an inconsistency.

---

## All EC2 instances: base hardening

Applies to both web and app tiers.

### Administrative access

* [ ] SSM Session Manager is the only administrative access mechanism.
* [ ] No SSH keys are provisioned for normal administration.
* [ ] No bastion host exists.
* [ ] No inbound SSH rule is present in the instance security groups.
* [ ] State Manager is used for recurring configuration enforcement.

### Authentication hardening

* [ ] Password authentication is disabled:

```text id="1w2a4s"
PasswordAuthentication no
```

* [ ] Root SSH login is disabled:

```text id="q1h2zw"
PermitRootLogin no
```

* [ ] Application services do not run as root.
* [ ] Unnecessary local accounts and services are removed or disabled where applicable.

### Host firewall

UFW is configured with:

* [ ] Default incoming policy: deny.
* [ ] Default outgoing policy: allow.
* [ ] Only application traffic required by the tier is explicitly permitted.
* [ ] SSH is not opened as an administrative exception.

Host-level firewall controls complement, rather than replace, AWS security groups.

### Monitoring and integrity

* [ ] CloudWatch Agent is installed and running.
* [ ] Required system/application logs are shipped to CloudWatch.
* [ ] Required host metrics are shipped to CloudWatch.
* [ ] AIDE file-integrity baseline is established.
* [ ] Auditd is installed and configured for host audit visibility.
* [ ] AIDE and auditd are managed through the Ansible hardening workflow.

### Instance metadata

* [ ] IMDSv2 is enforced through the EC2 launch template.
* [ ] `http_tokens = "required"`.
* [ ] `http_put_response_hop_limit = 1`.

IMDSv2 is a Terraform/launch-template control rather than an Ansible OS-hardening task.

### Deferred monitoring technology

* [ ] Wazuh is **not part of the current implemented architecture**.
* [ ] Wazuh remains a potential future monitoring enhancement and must not be represented as implemented validation coverage.

CloudWatch is the current approved monitoring path.

---

## Web tier: web-tier.yml

The web tier receives traffic only from the public ALB through the approved security-group relationship.

### Network exposure

* [ ] Web instances do not have a public IP.
* [ ] Web instances do not accept direct internet traffic.
* [ ] Web security group permits HTTPS/8443 only from the public ALB security group.
* [ ] No inbound SSH/RDP path exists.
* [ ] No direct internet ingress is permitted.

### Application process

* [ ] Web process runs as the non-root `webapp` service user.
* [ ] Web service does not run with root privileges.
* [ ] Required application files have appropriate ownership and permissions.
* [ ] Unnecessary services are disabled.

### Approved request path

```text id="z3j1xw"
Internet
    |
    v
CloudFront + WAF
    |
    | HTTP/80
    v
Public ALB
    |
    | HTTPS/8443
    v
Web tier
```

The public ALB → web connection is TLS protected.

The web tier does not expose an alternative HTTP application listener.

---

## App tier: app-tier.yml

The app tier receives traffic only from the internal ALB.

### Network exposure

* [ ] App instances do not have a public IP.
* [ ] App instances do not accept direct internet traffic.
* [ ] App security group permits HTTPS/8080 only from the internal ALB security group.
* [ ] No inbound SSH/RDP path exists.
* [ ] No direct web-tier-to-app-instance path bypassing the internal ALB is authorized.

### Application process

* [ ] App process runs as the non-root `appsvc` service user.
* [ ] App service does not run with root privileges.
* [ ] Required application files have appropriate ownership and permissions.
* [ ] Unnecessary services are disabled.

### Database credentials

* [ ] Application connects to RDS using the least-privilege `app_svc` credential.
* [ ] The credential is retrieved from Secrets Manager.
* [ ] The RDS master credential is never used by the application.
* [ ] The app IAM role can retrieve only the designated DB and Redis secrets.

### Approved request path

```text id="6s7xjv"
Web tier
    |
    | HTTPS/443
    v
Internal ALB
    |
    | HTTPS/8080
    v
App tier
```

The internal ALB is internal-only and has no internet-facing network path.

---

## Data tier: RDS MySQL

RDS is AWS-managed; OS-level hardening does not apply.

Security is established through Terraform, network controls, database configuration, IAM, encryption, and credential management.

* [ ] `publicly_accessible = false`.
* [ ] RDS is deployed in the private DB subnets.
* [ ] DB security group permits TCP/3306 only from the app security group.
* [ ] `require_secure_transport = ON`.
* [ ] `local_infile` is disabled.
* [ ] `storage_encrypted = true`.
* [ ] RDS uses the dedicated `rds` customer-managed KMS key.
* [ ] Automated backup retention is explicitly set to **7 days**.
* [ ] Deletion protection is enabled.
* [ ] Audit, error, general, and slow-query logs are exported to CloudWatch where supported by the selected RDS configuration.
* [ ] Application access uses the least-privilege `app_svc` database account.
* [ ] `app_svc` is restricted to the application's required database/schema privileges.
* [ ] Database-level host/source restrictions are applied as an additional control where supported.
* [ ] The RDS master credential is stored separately in Secrets Manager.
* [ ] The RDS master credential is not available to the app IAM role.
* [ ] The RDS master credential is not embedded in application configuration, Ansible, or Terraform plaintext configuration.

The database credential is created through the standalone DB bootstrap process rather than as a Terraform-managed database-user resource.

This avoids coupling the application credential lifecycle to Terraform `apply`/`destroy` operations.

---

## Data tier: ElastiCache Redis

ElastiCache is AWS-managed and therefore has no customer-managed OS layer.

* [ ] Redis is deployed privately.
* [ ] Redis security group permits access only from the app security group.
* [ ] `transit_encryption_enabled = true`.
* [ ] `at_rest_encryption_enabled = true`.
* [ ] ElastiCache uses the dedicated `elasticache` KMS key.
* [ ] Redis AUTH is enabled where required by the selected configuration.
* [ ] Redis AUTH token is stored in Secrets Manager.
* [ ] Redis AUTH token is separate from the RDS application credential.
* [ ] App IAM role can retrieve the Redis AUTH secret.
* [ ] Web IAM role cannot retrieve the Redis AUTH secret.
* [ ] Web security group has no authorized path to Redis.
* [ ] Two cache clusters are distributed across the two availability zones.

---

## Delivery mechanism: SSM + Ansible

OS hardening is delivered through AWS Systems Manager rather than SSH.

### State Manager

* [ ] SSM State Manager associations are configured for the web tier.
* [ ] SSM State Manager associations are configured for the app tier.
* [ ] Associations target instances using the approved `Role` tag.
* [ ] `AWS-ApplyAnsiblePlaybooks` is used for Ansible execution.
* [ ] Hardening is reapplied every **7 days** for configuration-drift correction.
* [ ] Failed associations are observable through SSM.

### Ansible bundle

* [ ] Playbook bundle is stored in a private S3 bucket.
* [ ] S3 bucket encryption uses the dedicated `ansible-bundle` KMS key.
* [ ] S3 versioning is enabled.
* [ ] Bucket access requires TLS.
* [ ] Instance roles have read-only object access.
* [ ] Instance roles cannot modify or delete the Ansible bundle.
* [ ] S3 `GetObject` permission is scoped to the required object path:

```text id="2s6xq9"
arn:aws:s3:::<ansible-bundle-bucket>/*
```

* [ ] No Ansible secrets are committed to Git.
* [ ] No RDS master credential is stored in the Ansible bundle.

Encryption and versioning protect the stored artifact but do not, by themselves, prove artifact authenticity. Any future artifact-signing or stronger supply-chain integrity mechanism must be separately implemented and validated.

---

## Security-group and host-firewall relationship

Host hardening and AWS network controls operate together.

### Web

```text id="xq3z9a"
Public ALB SG
      |
      | TCP/8443
      v
Web SG
      |
      v
UFW
      |
      v
Web application
```

### App

```text id="v7b2km"
Internal ALB SG
      |
      | TCP/8080
      v
App SG
      |
      v
UFW
      |
      v
App application
```

A connection must therefore satisfy both the AWS network boundary and the host-level firewall/application listener requirements.

---

## Hardening exclusions and accepted limitations

### CloudFront → Public ALB HTTP

CloudFront → Public ALB remains HTTP/80.

This is an explicitly accepted capstone limitation caused by the absence of an owned public domain and publicly trusted origin certificate.

It is not an OS-hardening exception.

Production remediation:

* owned public domain;
* ACM public certificate;
* HTTPS listener on the public ALB;
* CloudFront HTTPS-only origin protocol.

### AWS-managed data services

No OS-level hardening is performed on RDS or ElastiCache because AWS manages their underlying operating systems.

Their security posture is instead established through:

* private network placement;
* security groups;
* encryption;
* TLS;
* authentication;
* IAM;
* service configuration;
* backup and logging controls.

### Wazuh

Wazuh is deferred.

It must not be presented as implemented security monitoring in the capstone until it is actually deployed and validated.

---

## Validation model

Every hardening item follows the capstone's standard status model.

### Planned

The control exists in the design/documentation but has not yet been implemented.

### Implemented

The control exists in the deployed environment and corresponds to the Terraform or Ansible configuration.

### Validated

Live evidence demonstrates that the deployed control behaves as intended.

Evidence is stored under:

```text id="f9s3de"
evidence/validation/
```

Examples include:

* SSM association execution evidence;
* listening-port inspection;
* UFW status and rules;
* SSH configuration verification;
* IMDSv2 verification;
* TLS connection tests;
* AWS security-group exposure checks;
* RDS encryption/configuration checks;
* ElastiCache encryption checks;
* IAM negative-access tests.

A Terraform value or Ansible task alone is not sufficient to claim validation.

---

## Verification checklist

### EC2

* [ ] No public IP on web/app instances.
* [ ] No SSH ingress.
* [ ] No bastion host.
* [ ] SSM connectivity operational.
* [ ] Password authentication disabled.
* [ ] Root SSH login disabled.
* [ ] UFW enabled.
* [ ] Default-deny inbound firewall policy confirmed.
* [ ] CloudWatch Agent operational.
* [ ] AIDE baseline operational.
* [ ] Auditd operational.
* [ ] IMDSv2 enforced.
* [ ] Web service runs as `webapp`.
* [ ] App service runs as `appsvc`.

### Network

* [ ] Public ALB → Web uses HTTPS/8443.
* [ ] Web → Internal ALB uses HTTPS/443.
* [ ] Internal ALB → App uses HTTPS/8080.
* [ ] No direct internet ingress to web/app.
* [ ] Security groups use the approved trust chain.
* [ ] Host firewall rules match the AWS security-group model.

### RDS

* [ ] Private/non-public deployment confirmed.
* [ ] TLS enforcement confirmed.
* [ ] `local_infile` disabled.
* [ ] Dedicated RDS KMS key confirmed.
* [ ] 7-day backup retention confirmed.
* [ ] Deletion protection confirmed.
* [ ] Required log exports confirmed.
* [ ] `app_svc` least privilege confirmed.
* [ ] Master credential inaccessible to app IAM role.

### ElastiCache

* [ ] Private deployment confirmed.
* [ ] Transit encryption confirmed.
* [ ] At-rest encryption confirmed.
* [ ] Dedicated ElastiCache KMS key confirmed.
* [ ] AUTH token stored in Secrets Manager.
* [ ] Web tier cannot retrieve the Redis credential.

### Delivery

* [ ] State Manager associations operational.
* [ ] Associations target the correct tier tags.
* [ ] Seven-day reapplication configured.
* [ ] Ansible bundle stored privately.
* [ ] Ansible S3 encryption confirmed.
* [ ] S3 versioning confirmed.
* [ ] Instance `GetObject` access restricted to required objects.
* [ ] No plaintext credentials in the bundle.

---

## Related documents

* `docs/architecture/architecture-overview.md`
* `docs/architecture/trust-boundaries.md`
* `docs/architecture/threat-model.md`
* `docs/security/network-security.md`
* `docs/security/iam-strategy.md`
* `docs/security/data-protection.md`
* `scripts/validation/`
* `evidence/validation/`
* `ansible/`
* `infrastructure/modules/security/`
* `infrastructure/modules/compute/`
* `infrastructure/modules/data/`
