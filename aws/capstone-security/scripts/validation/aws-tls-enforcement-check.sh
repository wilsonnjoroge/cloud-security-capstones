#!/usr/bin/env bash
#
# aws-tls-enforcement-check.sh
#
# Validates TLS-in-transit configuration on the capstone data tier via
# the AWS API. Does NOT attempt a live plaintext connection — see
# validation-guide.md items 8/9 for that manual proof step.
#
# Usage:
#   ./aws-tls-enforcement-check.sh <db-instance-id> <cache-replication-group-id>

set -euo pipefail

DB_INSTANCE_ID="${1:?Usage: $0 <db-instance-id> <cache-replication-group-id>}"
CACHE_GROUP_ID="${2:?Usage: $0 <db-instance-id> <cache-replication-group-id>}"

ALL_PASS=true

echo "--- RDS: ${DB_INSTANCE_ID} ---"
INSTANCE=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" \
  --query "DBInstances[0]" --output json)

PUBLIC=$(echo "$INSTANCE" | jq -r '.PubliclyAccessible')
if [[ "$PUBLIC" == "false" ]]; then
  echo "PASS — not publicly accessible"
else
  echo "FAIL — PubliclyAccessible=true"
  ALL_PASS=false
fi

ENCRYPTED=$(echo "$INSTANCE" | jq -r '.StorageEncrypted')
if [[ "$ENCRYPTED" == "true" ]]; then
  echo "PASS — storage encrypted at rest"
else
  echo "FAIL — storage not encrypted at rest"
  ALL_PASS=false
fi

PARAM_GROUP=$(echo "$INSTANCE" | jq -r '.DBParameterGroups[0].DBParameterGroupName')
SECURE_TRANSPORT=$(aws rds describe-db-parameters --db-parameter-group-name "$PARAM_GROUP" \
  --query "Parameters[?ParameterName=='require_secure_transport'].ParameterValue" \
  --output text)

if [[ "${SECURE_TRANSPORT^^}" == "ON" ]]; then
  echo "PASS — require_secure_transport=ON"
else
  echo "FAIL — require_secure_transport=${SECURE_TRANSPORT:-unset} (expected ON)"
  ALL_PASS=false
fi

echo
echo "--- ElastiCache: ${CACHE_GROUP_ID} ---"
GROUP=$(aws elasticache describe-replication-groups \
  --replication-group-id "$CACHE_GROUP_ID" \
  --query "ReplicationGroups[0]" --output json)

TRANSIT=$(echo "$GROUP" | jq -r '.TransitEncryptionEnabled')
if [[ "$TRANSIT" == "true" ]]; then
  echo "PASS — transit encryption enabled"
else
  echo "FAIL — transit encryption not enabled"
  ALL_PASS=false
fi

AT_REST=$(echo "$GROUP" | jq -r '.AtRestEncryptionEnabled')
if [[ "$AT_REST" == "true" ]]; then
  echo "PASS — at-rest encryption enabled"
else
  echo "FAIL — at-rest encryption not enabled"
  ALL_PASS=false
fi

AUTH=$(echo "$GROUP" | jq -r '.AuthTokenEnabled')
if [[ "$AUTH" == "true" ]]; then
  echo "PASS — AUTH token required"
else
  echo "FAIL — no AUTH token configured"
  ALL_PASS=false
fi

echo
if $ALL_PASS; then
  echo "PASS — TLS-in-transit configuration verified on both RDS and ElastiCache"
  exit 0
else
  echo "FAIL — one or more TLS enforcement checks failed, see above"
  exit 1
fi
