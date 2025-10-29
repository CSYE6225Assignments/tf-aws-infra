#!/bin/bash
set -euo pipefail

# Log everything to file and console
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting User Data Script ==="
date

# Wait for network
sleep 10

# Install netcat for database connectivity check
apt-get update -y
apt-get install -y netcat-openbsd

# Get instance ID via IMDSv2
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
echo "Instance ID: $INSTANCE_ID"
echo "Environment: ${environment}"

# ========================================
# Configure CloudWatch Agent
# ========================================
echo "=== Configuring CloudWatch Agent ==="

# Replace placeholder in CloudWatch config
# Using %%{ENVIRONMENT}%% to avoid Terraform template parsing issues
sed -i 's/$${ENVIRONMENT}/${environment}/g' /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json

# Verify replacement worked
echo "CloudWatch config after environment substitution:"
grep -i "log_group_name" /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json || true

# Start CloudWatch Agent
echo "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-config.json

# Ensure agent starts on reboot
systemctl enable amazon-cloudwatch-agent

# Verify agent started
sleep 3
AGENT_STATUS=$(/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "CloudWatch Agent status: $AGENT_STATUS"

if [ "$AGENT_STATUS" = "running" ]; then
    echo " CloudWatch Agent started successfully"
else
    echo " CloudWatch Agent failed to start"
    tail -20 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log || true
fi

# ========================================
# Configure Application
# ========================================
echo "=== Creating application.properties ==="

cat > /opt/csye6225/application.properties <<EOF
# Server Configuration
server.port=8080

# Application Configuration
spring.application.name=csye6225

# Database Configuration (RDS)
spring.datasource.url=jdbc:mysql://${db_hostname}:${db_port}/${db_name}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
spring.datasource.username=${db_username}
spring.datasource.password=${db_password}
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# Connection Pool Settings
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=2
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.register-mbeans=true

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
spring.jpa.properties.hibernate.jdbc.time_zone=UTC

# AWS Configuration
aws.region=${aws_region}
aws.s3.bucket-name=${s3_bucket_name}
storage.type=s3

# File Upload Configuration
spring.servlet.multipart.enabled=true
spring.servlet.multipart.max-file-size=5MB
spring.servlet.multipart.max-request-size=5MB

# Actuator Configuration (Disable Endpoints)
management.endpoints.web.exposure.include=
management.endpoints.jmx.exposure.include=

# Metrics Configuration (StatsD Export)
management.statsd.metrics.export.enabled=true
management.statsd.metrics.export.flavor=etsy
management.statsd.metrics.export.host=localhost
management.statsd.metrics.export.port=8125
management.metrics.distribution.percentiles-histogram.all=false

# Environment
ENVIRONMENT=${environment}
EOF

# Set ownership and permissions
chown csye6225:csye6225 /opt/csye6225/application.properties
chmod 640 /opt/csye6225/application.properties

echo " Application properties created"

# ========================================
# Wait for Database
# ========================================
echo "=== Waiting for database ==="
for i in {1..30}; do
  if nc -z -w5 ${db_hostname} ${db_port} 2>/dev/null; then
    echo " Database is reachable!"
    break
  fi
  echo "Attempt $i/30: Waiting for database..."
  sleep 10
done


# ========================================
# Start Application
# ========================================
echo "=== Starting application ==="
systemctl daemon-reload
systemctl enable csye6225.service
systemctl restart csye6225.service

# Wait for application to start
sleep 5

# Check application status
systemctl status csye6225.service --no-pager || true

# Check if application is listening on port 8080
if ss -ltn | grep -q ":8080 "; then
    echo " Application is listening on port 8080"
else
    echo " Application may not be listening on port 8080"
fi

echo "=== User Data Complete ==="
date