#!/usr/bin/env python3
"""
aws-tls-enforcement-check.py

Validates TLS-in-transit enforcement on the capstone data tier:
  - RDS: require_secure_transport = ON (MySQL 8 parameter), not publicly accessible
  - ElastiCache: transit_encryption_enabled = true

This checks configuration via the AWS API. It does NOT attempt a live
plaintext connection — that's a separate, manual proof step documented
in validation-guide.md (item 8/9), since it requires network access
from inside the VPC and isn't safe to run unattended against
production-shaped credentials.

Usage:
    python3 aws-tls-enforcement-check.py \
        --db-instance-id capstone-mysql \
        --cache-replication-group-id capstone-redis
"""

import argparse
import sys

import boto3


def check_rds(rds, db_instance_id: str) -> bool:
    print(f"--- RDS: {db_instance_id} ---")
    resp = rds.describe_db_instances(DBInstanceIdentifier=db_instance_id)
    instance = resp["DBInstances"][0]

    ok = True

    publicly_accessible = instance.get("PubliclyAccessible", True)
    if publicly_accessible:
        print("FAIL — PubliclyAccessible=True")
        ok = False
    else:
        print("PASS — not publicly accessible")

    storage_encrypted = instance.get("StorageEncrypted", False)
    if storage_encrypted:
        print("PASS — storage encrypted at rest")
    else:
        print("FAIL — storage not encrypted at rest")
        ok = False

    param_group_name = instance["DBParameterGroups"][0]["DBParameterGroupName"]
    params = rds.describe_db_parameters(DBParameterGroupName=param_group_name)["Parameters"]
    secure_transport = next(
        (p for p in params if p["ParameterName"] == "require_secure_transport"), None
    )

    if secure_transport and secure_transport.get("ParameterValue", "").upper() == "ON":
        print("PASS — require_secure_transport=ON")
    else:
        current = secure_transport.get("ParameterValue") if secure_transport else "unset"
        print(f"FAIL — require_secure_transport={current} (expected ON)")
        ok = False

    return ok


def check_elasticache(ec, replication_group_id: str) -> bool:
    print(f"--- ElastiCache: {replication_group_id} ---")
    resp = ec.describe_replication_groups(ReplicationGroupId=replication_group_id)
    group = resp["ReplicationGroups"][0]

    ok = True

    if group.get("TransitEncryptionEnabled", False):
        print("PASS — transit encryption enabled")
    else:
        print("FAIL — transit encryption not enabled")
        ok = False

    if group.get("AtRestEncryptionEnabled", False):
        print("PASS — at-rest encryption enabled")
    else:
        print("FAIL — at-rest encryption not enabled")
        ok = False

    if group.get("AuthTokenEnabled", False):
        print("PASS — AUTH token required")
    else:
        print("FAIL — no AUTH token configured")
        ok = False

    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db-instance-id", required=True)
    parser.add_argument("--cache-replication-group-id", required=True)
    parser.add_argument("--region", default=None)
    args = parser.parse_args()

    rds = boto3.client("rds", region_name=args.region)
    ec = boto3.client("elasticache", region_name=args.region)

    rds_ok = check_rds(rds, args.db_instance_id)
    print()
    cache_ok = check_elasticache(ec, args.cache_replication_group_id)
    print()

    if rds_ok and cache_ok:
        print("PASS — TLS-in-transit configuration verified on both RDS and ElastiCache")
        sys.exit(0)
    else:
        print("FAIL — one or more TLS enforcement checks failed, see above")
        sys.exit(1)


if __name__ == "__main__":
    main()
