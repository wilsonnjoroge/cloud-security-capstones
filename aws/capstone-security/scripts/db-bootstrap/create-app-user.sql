-- One-time (or post-rotation) bootstrap for the least-privilege
-- app_svc MySQL user. Run via bootstrap-app-user.sh, which tunnels
-- through SSM rather than exposing RDS directly.

CREATE USER IF NOT EXISTS 'app_svc'@'{{APP_SUBNET_CIDR_PREFIX}}' IDENTIFIED BY '{{APP_DB_PASSWORD}}';
GRANT SELECT, INSERT, UPDATE, DELETE ON capstone_app.* TO 'app_svc'@'{{APP_SUBNET_CIDR_PREFIX}}';
FLUSH PRIVILEGES;
