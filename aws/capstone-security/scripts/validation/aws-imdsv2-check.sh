#!/usr/bin/env bash
#
# aws-imdsv2-check.sh
#
# Validates that IMDSv2 is enforced on capstone web/app tier instances,
# via the EC2 API (not a curl from inside the instance). Requires the
# AWS CLI and jq.
#
# Usage:
#   ./aws-imdsv2-check.sh [tag-key] [tag-value1,tag-value2,...]
#
# Exit code 0 if every matched instance enforces IMDSv2, 1 otherwise.

set -euo pipefail

TAG_KEY="${1:-Role}"
TAG_VALUES="${2:-web,app}"
IFS=',' read -ra VALUES <<< "$TAG_VALUES"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:${TAG_KEY},Values=${VALUES[*]// /,}" \
            "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)

if [[ -z "$INSTANCE_IDS" ]]; then
  echo "No instances found matching tag ${TAG_KEY}=${TAG_VALUES}"
  exit 1
fi

ALL_PASS=true

for id in $INSTANCE_IDS; do
  DETAILS=$(aws ec2 describe-instances --instance-ids "$id" \
    --query "Reservations[0].Instances[0].MetadataOptions" --output json)

  HTTP_TOKENS=$(echo "$DETAILS" | jq -r '.HttpTokens // "optional"')
  HTTP_ENDPOINT=$(echo "$DETAILS" | jq -r '.HttpEndpoint // "enabled"')

  if [[ "$HTTP_ENDPOINT" == "disabled" ]]; then
    echo "${id}: IMDS disabled entirely — trivially compliant"
  elif [[ "$HTTP_TOKENS" == "required" ]]; then
    echo "${id}: IMDSv2 enforced (HttpTokens=required)"
  else
    echo "${id}: FAIL — HttpTokens=${HTTP_TOKENS} (IMDSv1 still usable)"
    ALL_PASS=false
  fi
done

echo
INSTANCE_COUNT=$(echo "$INSTANCE_IDS" | wc -w)
if $ALL_PASS; then
  echo "PASS — ${INSTANCE_COUNT} instance(s) checked, IMDSv2 enforced on all"
  exit 0
else
  echo "FAIL — one or more of ${INSTANCE_COUNT} instance(s) do not enforce IMDSv2"
  exit 1
fi
