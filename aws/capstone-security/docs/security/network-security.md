# Network Security: AWS Capstone

## Purpose

This document is the source of truth for network segmentation, routing, security groups, subnet-level controls, VPC endpoints, host firewalls, and network visibility across the capstone environment.

The network design implements the trust boundaries defined in:

* `docs/architecture/architecture-overview.md`
* `docs/architecture/trust-boundaries.md`
* `docs/architecture/threat-model.md`

The design follows a deny-by-default model and uses multiple independent control layers rather than relying on a single network control.

---

## VPC and subnet layout

The environment uses one VPC across two Availability Zones.

```text
VPC: 10.0.0.0/16
```

DNS support and DNS hostnames are enabled.

Each Availability Zone contains four subnet tiers:

1. Public
2. Web
3. App
4. DB

This produces eight subnets in total.

| Tier   | AZ-A         | AZ-B         | Purpose                   | Internet path             |
| ------ | ------------ | ------------ | ------------------------- | ------------------------- |
| Public | 10.0.0.0/24  | 10.0.1.0/24  | Public ALB / NAT gateways | IGW                       |
| Web    | 10.0.10.0/24 | 10.0.11.0/24 | Web-tier ASG              | Per-AZ NAT                |
| App    | 10.0.20.0/24 | 10.0.21.0/24 | App-tier ASG              | Per-AZ NAT                |
| DB     | 10.0.30.0/24 | 10.0.31.0/24 | RDS / ElastiCache         | No default internet route |

The subnet structure is intentionally identical across the two Availability Zones.

---

## Routing model

### Public subnets

The public route table contains:

```text id="6gk9b4"
0.0.0.0/0 → Internet Gateway
```

Public subnets host the public-facing network components that require internet-facing connectivity, including the public ALB and NAT gateways.

### Web subnets

Each web subnet has its own route table.

The default route points to the NAT gateway in the same Availability Zone:

```text id="7j3mqa"
0.0.0.0/0 → NAT Gateway in same AZ
```

This provides outbound internet access where required without giving web instances an inbound internet path.

### App subnets

Each app subnet has its own route table.

The default route points to the NAT gateway in the same Availability Zone:

```text id="b1s6fd"
0.0.0.0/0 → NAT Gateway in same AZ
```

This provides permitted outbound connectivity while preventing unsolicited inbound internet connectivity.

### DB subnets

The DB route tables contain only the implicit VPC-local route.

There is no:

```text id="z2v8ps"
0.0.0.0/0
```

route to an IGW or NAT gateway.

RDS and ElastiCache therefore have no general internet egress path through the VPC routing configuration.

This is a network boundary control. It does not make claims about AWS-managed service internals outside the customer's VPC routing configuration.

---

## Approved request path

The application request path is:

```text id="1t0n7r"
Internet
    |
    | HTTPS
    v
CloudFront + WAF
    |
    | HTTP/80
    v
Public ALB
    |
    | HTTPS/8443
    v
Web ASG
    |
    | HTTPS/443
    v
Internal ALB
    |
    | HTTPS/8080
    v
App ASG
    |
    +---- HTTPS/TLS ----> RDS MySQL
    |
    +---- TLS ----------> ElastiCache Redis
```

The CloudFront → Public ALB HTTP connection is a deliberate and documented architectural limitation.

All subsequent application-tier hops are TLS protected.

---

## Security-group trust chain

Security groups form an explicit tier-to-tier trust chain.

```text id="6q5w8r"
CloudFront
    |
    | HTTP/80
    v
Public ALB SG
    |
    | HTTPS/8443
    v
Web SG
    |
    | HTTPS/443
    v
Internal ALB SG
    |
    | HTTPS/8080
    v
App SG
    |
    +------ TCP/3306 ------> RDS SG
    |
    +------ TCP/6379 ------> ElastiCache SG
```

### Public ALB

Inbound:

* TCP/80 from the AWS-managed CloudFront origin-facing prefix list.

Outbound:

* TCP/8443 to the web-tier security group.

The public ALB does **not** permit:

```text id="m0x3qz"
0.0.0.0/0
```

as a generic inbound source.

The CloudFront prefix list is the explicit exception required for the CloudFront origin path.

### Web tier

Inbound:

* TCP/8443 from the public ALB security group.

Outbound:

* TCP/443 to the internal ALB security group.
* Required HTTPS access to approved VPC endpoint security groups for AWS service APIs.
* Other outbound traffic only where explicitly required by the deployment.

There is no inbound SSH or RDP path.

### Internal ALB

The internal ALB is not internet-facing.

Inbound:

* TCP/443 from the web security group.

Outbound:

* TCP/8080 to the app security group.

The internal ALB has private DNS/network reachability inside the VPC but no internet-facing network path.

### App tier

Inbound:

* TCP/8080 from the internal ALB security group.

Outbound:

* TCP/3306 to the RDS security group.
* TCP/6379 to the ElastiCache security group.
* HTTPS/443 to the approved VPC endpoint security groups for required AWS services.

There is no direct inbound path from the internet.

### RDS

Inbound:

* TCP/3306 from the app security group only.

No internet-facing security-group ingress is permitted.

### ElastiCache

Inbound:

* TCP/6379 from the app security group only.

No internet-facing security-group ingress is permitted.

---

## Security-group design principles

The security-group model follows these principles:

* No unnecessary inbound `0.0.0.0/0`.
* Security-group references are preferred over CIDR-based trust between AWS tiers.
* Each tier trusts only the immediately required upstream component.
* Database access is limited to the app tier.
* Redis access is limited to the app tier.
* Web instances do not directly trust app instances.
* App instances do not directly trust web instances for inbound application traffic.
* No SSH administration path exists.
* Network segmentation is enforced independently of IAM.

The security-group chain is therefore both a positive authorization model and a negative isolation model.

---

## Network ACLs

Network ACLs provide a second, stateless subnet-level control layer behind the stateful security groups.

NACLs must be configured deliberately for the subnet tiers and must support the required application traffic and return traffic.

They must not be treated as a substitute for security groups.

The design intent is:

```text id="3k7w2m"
Internet-facing controls
        |
        v
Security Groups
        |
        v
NACLs
        |
        v
Host firewall
        |
        v
Application listener
```

NACL rules must be validated against the deployed subnet and traffic requirements.

A permissive NACL is not considered a security control merely because a security group provides the primary restriction.

---

## VPC endpoints

VPC endpoints provide private AWS-service connectivity for services required by the private tiers.

The architecture includes:

### S3

* S3 gateway endpoint.
* Used for private access to the Ansible bundle without requiring the Ansible retrieval path to traverse the NAT gateway.

### Systems Manager

Interface endpoints for:

* SSM
* SSMMessages
* EC2Messages

These support SSM-managed instance operation without requiring administrative traffic to traverse the public internet.

### Secrets Manager

* Secrets Manager interface endpoint.
* Allows the app tier to retrieve its authorized secrets through private VPC connectivity.

### CloudWatch Logs

* CloudWatch Logs interface endpoint.
* Supports private delivery of applicable logs to CloudWatch Logs from resources that use the endpoint.

### Endpoint security group

The VPC endpoint security group permits:

```text id="2k8v1p"
TCP/443
Source: VPC CIDR / approved private workload sources
```

Where practical, endpoint access should be limited to the tiers that actually require the service.

For example:

* Web tier requires SSM-related and configuration-management access.
* App tier requires SSM-related access and Secrets Manager access.
* Both tiers may require CloudWatch Logs access depending on the deployed CloudWatch Agent configuration.

---

## NAT gateway design

NAT gateways provide outbound internet connectivity for private web and app subnets where required.

The design uses one NAT gateway per Availability Zone.

```text id="p3n9xs"
Web-A → NAT-A
App-A → NAT-A

Web-B → NAT-B
App-B → NAT-B
```

This provides:

* AZ-local outbound routing;
* reduced cross-AZ dependency;
* continued outbound connectivity if one AZ experiences a failure.

NAT is not used as an inbound path.

AWS-service traffic that can use VPC endpoints should use those endpoints instead of unnecessarily traversing NAT.

---

## Host-level firewall

UFW provides defense in depth on the web and app EC2 instances.

The Ansible base-hardening role configures:

```text id="v9c5jw"
Default incoming: DENY
Default outgoing: ALLOW
```

Explicit application rules are then applied per tier.

### Web

Allow only:

```text id="3f1r8c"
TCP/8443
Source: approved web-tier upstream path
```

### App

Allow only:

```text id="q5j7xb"
TCP/8080
Source: approved app-tier upstream path
```

The exact implementation must remain consistent with the AWS security-group design.

UFW is defense in depth.

It does not compensate for an incorrectly broad security group.

---

## VPC Flow Logs

VPC Flow Logs are enabled at the VPC level.

The configuration captures traffic according to the approved all-traffic visibility requirement.

Logs are:

* delivered to CloudWatch Logs;
* protected with the dedicated `flow-logs` KMS key;
* retained for **30 days**;
* delivered through the dedicated flow-log IAM role.

Flow Logs provide network telemetry for:

* allowed traffic;
* rejected traffic;
* unexpected communication attempts;
* lateral-movement investigation;
* security-group/NACL troubleshooting;
* incident-response analysis.

Flow Logs are visibility controls, not inline blocking controls.

---

## Network security validation

The following must be validated against the deployed environment.

### Security groups

* [ ] Confirm no unnecessary inbound security group rule uses `0.0.0.0/0`.
* [ ] Confirm the public ALB inbound HTTP/80 rule uses the AWS-managed CloudFront prefix list.
* [ ] Confirm public ALB → web is TCP/8443.
* [ ] Confirm web → internal ALB is TCP/443.
* [ ] Confirm internal ALB → app is TCP/8080.
* [ ] Confirm app → RDS is TCP/3306.
* [ ] Confirm app → Redis is TCP/6379.
* [ ] Confirm no inbound SSH/RDP path exists.
* [ ] Confirm web has no security-group-authorized direct path to RDS or Redis.
* [ ] Confirm app access to AWS service endpoints is limited to required services.

### Routing

* [ ] Confirm public subnets route through the IGW.
* [ ] Confirm each web subnet uses its local-AZ NAT gateway.
* [ ] Confirm each app subnet uses its local-AZ NAT gateway.
* [ ] Confirm DB route tables have no default internet route.
* [ ] Confirm DB subnets do not route through a NAT gateway or IGW.

### VPC endpoints

* [ ] Confirm S3 gateway endpoint exists.
* [ ] Confirm SSM endpoint exists.
* [ ] Confirm SSMMessages endpoint exists.
* [ ] Confirm EC2Messages endpoint exists where required by the selected SSM implementation.
* [ ] Confirm Secrets Manager endpoint exists.
* [ ] Confirm CloudWatch Logs endpoint exists.
* [ ] Confirm endpoint route tables and endpoint policies are correctly associated.
* [ ] Confirm endpoint security groups allow only required HTTPS sources.

### NACLs

* [ ] Confirm NACL rules are explicitly configured for the required subnet traffic.
* [ ] Confirm required return traffic is permitted.
* [ ] Confirm unnecessary inbound traffic is not permitted.
* [ ] Confirm NACL configuration does not silently bypass the intended segmentation model.

### Host firewall

* [ ] Confirm UFW is enabled on web instances.
* [ ] Confirm UFW is enabled on app instances.
* [ ] Confirm default inbound policy is deny.
* [ ] Confirm only required application ports are permitted.

### Flow Logs

* [ ] Confirm VPC Flow Logs are enabled.
* [ ] Confirm logs are actually arriving in CloudWatch Logs.
* [ ] Confirm the flow-log destination uses the dedicated KMS key.
* [ ] Confirm retention is 30 days.
* [ ] Confirm flow-log delivery uses the dedicated IAM role.

---

## Validation status

Network controls follow the capstone-wide status model.

### Planned

The control is documented but not yet deployed.

### Implemented

The control exists in the deployed AWS environment.

### Validated

Live evidence demonstrates that the deployed control behaves as intended.

Validation evidence belongs under:

```text id="j8m4qv"
evidence/validation/
```

Relevant validation tooling belongs under:

```text id="x1d7ks"
scripts/validation/
```

The validation process must test actual deployed exposure and communication paths rather than relying only on Terraform configuration.

---

## Accepted architectural limitation

### CloudFront → Public ALB

The CloudFront-to-public-ALB origin connection remains HTTP/80.

This is deliberate and documented.

The limitation exists because the capstone does not currently use an owned public domain with a publicly trusted origin certificate.

Production remediation is:

1. Use an owned domain.
2. Provision a publicly trusted ACM certificate.
3. Enable HTTPS on the public ALB.
4. Configure CloudFront for HTTPS-only origin communication.
5. Remove the HTTP origin dependency.

This is the only intentionally unencrypted application-network hop in the approved request path.

---

## Related documents

* `docs/architecture/architecture-overview.md`
* `docs/architecture/trust-boundaries.md`
* `docs/architecture/threat-model.md`
* `docs/security/iam-strategy.md`
* `docs/security/data-protection.md`
* `docs/security/server-hardening.md`
* `infrastructure/modules/network/`
* `infrastructure/modules/security/`
* `scripts/validation/`
* `evidence/validation/`
