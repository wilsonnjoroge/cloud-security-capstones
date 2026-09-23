#!/usr/bin/env python3
"""
aws-port-exposure-check.py

Validates that web/app tier security groups only permit the expected
ports, from the expected source (never 0.0.0.0/0 on anything but the
public ALB's HTTP/HTTPS listeners).

Checks security group ingress rules via the EC2 API — configuration
proof, not a live network scan. For a live scan from inside the VPC,
see validation-guide.md item 4/5.

Usage:
    python3 aws-port-exposure-check.py \
        --web-sg-id sg-xxxx --web-allowed-ports 80 443 \
        --app-sg-id sg-yyyy --app-allowed-ports 8080
"""

import argparse
import sys

import boto3


def check_security_group(ec2, sg_id: str, allowed_ports: list[int], tier_name: str) -> bool:
    print(f"--- {tier_name} tier SG: {sg_id} ---")
    resp = ec2.describe_security_groups(GroupIds=[sg_id])
    sg = resp["SecurityGroups"][0]

    ok = True
    seen_ports = set()

    for rule in sg.get("IpPermissions", []):
        from_port = rule.get("FromPort")
        to_port = rule.get("ToPort")
        if from_port is None:
            continue  # covers all-traffic rules, handled separately below

        seen_ports.add(from_port)

        if from_port not in allowed_ports:
            print(f"FAIL — unexpected port open: {from_port}-{to_port}")
            ok = False
            continue

        for ip_range in rule.get("IpRanges", []):
            cidr = ip_range["CidrIp"]
            if cidr == "0.0.0.0/0":
                print(f"FAIL — port {from_port} open to 0.0.0.0/0 (should be SG/CIDR-scoped)")
                ok = False
            else:
                print(f"PASS — port {from_port} scoped to {cidr}")

        for sg_ref in rule.get("UserIdGroupPairs", []):
            print(f"PASS — port {from_port} scoped to security group {sg_ref['GroupId']}")

    unopened = set(allowed_ports) - seen_ports
    if unopened:
        print(f"NOTE — expected ports not found in ingress rules: {sorted(unopened)}")

    # Check for any wide-open "allow all" rule (IpProtocol=-1)
    for rule in sg.get("IpPermissions", []):
        if rule.get("IpProtocol") == "-1":
            for ip_range in rule.get("IpRanges", []):
                if ip_range["CidrIp"] == "0.0.0.0/0":
                    print("FAIL — all-traffic rule open to 0.0.0.0/0")
                    ok = False

    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--web-sg-id")
    parser.add_argument("--web-allowed-ports", nargs="+", type=int, default=[80, 443])
    parser.add_argument("--app-sg-id")
    parser.add_argument("--app-allowed-ports", nargs="+", type=int, default=[8080])
    parser.add_argument("--region", default=None)
    args = parser.parse_args()

    if not args.web_sg_id and not args.app_sg_id:
        parser.error("Provide at least one of --web-sg-id or --app-sg-id")

    ec2 = boto3.client("ec2", region_name=args.region)
    all_pass = True

    if args.web_sg_id:
        all_pass = check_security_group(ec2, args.web_sg_id, args.web_allowed_ports, "Web") and all_pass
        print()

    if args.app_sg_id:
        all_pass = check_security_group(ec2, args.app_sg_id, args.app_allowed_ports, "App") and all_pass
        print()

    if all_pass:
        print("PASS — no unexpected port exposure found")
        sys.exit(0)
    else:
        print("FAIL — one or more security groups expose unexpected ports/sources")
        sys.exit(1)


if __name__ == "__main__":
    main()
