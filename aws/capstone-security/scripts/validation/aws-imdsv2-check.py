#!/usr/bin/env python3
"""
aws-imdsv2-check.py

Validates that IMDSv2 is enforced on capstone web/app tier instances.
Checks the launch-template / instance MetadataOptions via the EC2 API
rather than curling from inside the instance — this proves the control
is applied at the infrastructure level, not just true on one box today.

Usage:
    python3 aws-imdsv2-check.py --tag-key Role --tag-values web app

Exit code 0 if every matched instance enforces IMDSv2, 1 otherwise.
"""

import argparse
import sys

import boto3


def get_matching_instances(ec2, tag_key: str, tag_values: list[str]):
    paginator = ec2.get_paginator("describe_instances")
    filters = [
        {"Name": f"tag:{tag_key}", "Values": tag_values},
        {"Name": "instance-state-name", "Values": ["running", "pending", "stopped"]},
    ]
    instances = []
    for page in paginator.paginate(Filters=filters):
        for reservation in page["Reservations"]:
            instances.extend(reservation["Instances"])
    return instances


def check_instance(instance: dict) -> tuple[bool, str]:
    instance_id = instance["InstanceId"]
    metadata_options = instance.get("MetadataOptions", {})
    http_tokens = metadata_options.get("HttpTokens", "optional")
    http_endpoint = metadata_options.get("HttpEndpoint", "enabled")

    if http_endpoint == "disabled":
        return True, f"{instance_id}: IMDS disabled entirely — trivially compliant"

    if http_tokens == "required":
        return True, f"{instance_id}: IMDSv2 enforced (HttpTokens=required)"

    return False, f"{instance_id}: FAIL — HttpTokens={http_tokens} (IMDSv1 still usable)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag-key", default="Role", help="Tag key to filter instances by")
    parser.add_argument(
        "--tag-values",
        nargs="+",
        default=["web", "app"],
        help="Tag values to include (space-separated)",
    )
    parser.add_argument("--region", default=None, help="AWS region override")
    args = parser.parse_args()

    ec2 = boto3.client("ec2", region_name=args.region)
    instances = get_matching_instances(ec2, args.tag_key, args.tag_values)

    if not instances:
        print(f"No instances found matching tag {args.tag_key}={args.tag_values}")
        sys.exit(1)

    all_pass = True
    for instance in instances:
        passed, message = check_instance(instance)
        print(message)
        all_pass = all_pass and passed

    print()
    if all_pass:
        print(f"PASS — {len(instances)} instance(s) checked, IMDSv2 enforced on all")
        sys.exit(0)
    else:
        print(f"FAIL — one or more of {len(instances)} instance(s) do not enforce IMDSv2")
        sys.exit(1)


if __name__ == "__main__":
    main()
