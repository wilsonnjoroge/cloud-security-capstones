#!/usr/bin/env bash
#
# bootstrap-app-user.sh
#
# One-time (or post-rotation) bootstrap: creates the least-privilege
# app_svc MySQL user via an SSM port-forward tunnel through an
# app-tier instance. Requires: AWS CLI, Session Manager plugin, mysql
# client, jq — all local.
#
# Usage: ./bootstrap-app-user.sh <app-tier-instance-id> <rds-endpoint>
#
# IMPORTANT: replace the hardcoded 10.0.2.% host below with your
# actual app subnet CIDR prefix from vpc.tf before running.

set -euo pipefail

APP_INSTANCE_ID="${1:?Usage: $0 <app-tier-instance-id> <rds-endpoint>}"
RDS_ENDPOINT="${2:?Usage: $0 <app-tier-instance-id> <rds-endpoint>}"
LOCAL_PORT=13306

MASTER_SECRET_ARN=$(aws secretsmanager list-secrets \
  --query "SecretList[?contains(Name, 'rds-master')].ARN" --output text)
MASTER_CREDS=$(aws secretsmanager get-secret-value \
  --secret-id "$MASTER_SECRET_ARN" --query SecretString --output text)
MASTER_USER=$(echo "$MASTER_CREDS" | jq -r .username)
MASTER_PASS=$(echo "$MASTER_CREDS" | jq -r .password)

APP_SECRET_ARN=$(aws secretsmanager list-secrets \
  --query "SecretList[?contains(Name, 'app-db-user')].ARN" --output text)
APP_PASS=$(aws secretsmanager get-secret-value \
  --secret-id "$APP_SECRET_ARN" --query SecretString --output text | jq -r .password)

echo "Opening SSM tunnel to RDS via $APP_INSTANCE_ID..."
aws ssm start-session \
  --target "$APP_INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$RDS_ENDPOINT\"],\"portNumber\":[\"3306\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" &
TUNNEL_PID=$!
trap 'kill "$TUNNEL_PID" 2>/dev/null || true' EXIT
sleep 5   # let the tunnel establish before connecting

echo "Applying app_svc grant..."
mysql -h 127.0.0.1 -P "$LOCAL_PORT" -u "$MASTER_USER" -p"$MASTER_PASS" <<SQL
CREATE USER IF NOT EXISTS 'app_svc'@'10.0.2.%' IDENTIFIED BY '${APP_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE ON capstone_app.* TO 'app_svc'@'10.0.2.%';
FLUSH PRIVILEGES;
SQL

echo "Done — app_svc created with scoped grants, tunnel closing."
