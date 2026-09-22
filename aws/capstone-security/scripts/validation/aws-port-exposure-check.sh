#!/usr/bin/env bash
#
# aws-port-exposure-check.sh
#
# Validates that web/app tier security groups only permit the expected
# ports, from the expected source. Checks ingress rules via the EC2
# API — configuration proof, not a live network scan.
#
# Usage:
#   ./aws-port-exposure-check.sh <sg-id> <tier-name> <port1,port2,...>
#
# Example:
#   ./aws-port-exposure-check.sh sg-0123abc Web 80,443
#   ./aws-port-exposure-check.sh sg-0456def App 8080

set -euo pipefail

SG_ID="${1:?Usage: $0 <sg-id> <tier-name> <allowed-ports-comma-separated>}"
TIER_NAME="${2:?Usage: $0 <sg-id> <tier-name> <allowed-ports-comma-separated>}"
ALLOWED_PORTS="${3:?Usage: $0 <sg-id> <tier-name> <allowed-ports-comma-separated>}"
IFS=',' read -ra PORTS <<< "$ALLOWED_PORTS"

echo "--- ${TIER_NAME} tier SG: ${SG_ID} ---"

SG=$(aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query "SecurityGroups[0]" --output json)

ALL_PASS=true

RULE_COUNT=$(echo "$SG" | jq '.IpPermissions | length')

for i in $(seq 0 $((RULE_COUNT - 1))); do
  RULE=$(echo "$SG" | jq ".IpPermissions[$i]")
  FROM_PORT=$(echo "$RULE" | jq -r '.FromPort // "null"')
  PROTOCOL=$(echo "$RULE" | jq -r '.IpProtocol')

  if [[ "$PROTOCOL" == "-1" ]]; then
    HAS_OPEN=$(echo "$RULE" | jq '[.IpRanges[]? | select(.CidrIp == "0.0.0.0/0")] | length')
    if [[ "$HAS_OPEN" -gt 0 ]]; then
      echo "FAIL — all-traffic rule open to 0.0.0.0/0"
      ALL_PASS=false
    fi
    continue
  fi

  if [[ "$FROM_PORT" == "null" ]]; then
    continue
  fi

  MATCH=false
  for p in "${PORTS[@]}"; do
    if [[ "$p" == "$FROM_PORT" ]]; then
      MATCH=true
    fi
  done

  if [[ "$MATCH" == "false" ]]; then
    echo "FAIL — unexpected port open: ${FROM_PORT}"
    ALL_PASS=false
    continue
  fi

  CIDR_COUNT=$(echo "$RULE" | jq '.IpRanges | length')
  for j in $(seq 0 $((CIDR_COUNT - 1))); do
    CIDR=$(echo "$RULE" | jq -r ".IpRanges[$j].CidrIp")
    if [[ "$CIDR" == "0.0.0.0/0" ]]; then
      echo "FAIL — port ${FROM_PORT} open to 0.0.0.0/0 (should be SG/CIDR-scoped)"
      ALL_PASS=false
    else
      echo "PASS — port ${FROM_PORT} scoped to ${CIDR}"
    fi
  done

  SG_REF_COUNT=$(echo "$RULE" | jq '.UserIdGroupPairs | length')
  for j in $(seq 0 $((SG_REF_COUNT - 1))); do
    REF_SG=$(echo "$RULE" | jq -r ".UserIdGroupPairs[$j].GroupId")
    echo "PASS — port ${FROM_PORT} scoped to security group ${REF_SG}"
  done
done

echo
if $ALL_PASS; then
  echo "PASS — no unexpected port exposure found on ${TIER_NAME} tier"
  exit 0
else
  echo "FAIL — ${TIER_NAME} tier security group exposes unexpected ports/sources"
  exit 1
fi
