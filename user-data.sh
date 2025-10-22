#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting User Data Script ==="
date

# Wait for network
sleep 10

# Install netcat for database connectivity check
apt-get update -y
apt-get install -y netcat-openbsd

# Create application.properties with RDS and S3 configuration
cat > /opt/csye6225/application.properties <<EOF
# Server Configuration
server.port=8080

# Database Configuration (RDS)
spring.datasource.url=jdbc:mysql://${db_hostname}:${db_port}/${db_name}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
spring.datasource.username=${db_username}
spring.datasource.password=${db_password}
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# Connection Pool Settings
spring.datasource.hikari.maximum-pool-size=10
spring.datasource.hikari.minimum-idle=2
spring.datasource.hikari.connection-timeout=30000

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
EOF

# Set ownership and permissions
chown csye6225:csye6225 /opt/csye6225/application.properties
chmod 640 /opt/csye6225/application.properties

echo "=== Application properties created ==="

# Wait for RDS to be ready
echo "=== Waiting for database ==="
for i in {1..30}; do
  if nc -z -w5 ${db_hostname} ${db_port} 2>/dev/null; then
    echo "Database is reachable!"
    break
  fi
  echo "Attempt $i/30: Waiting..."
  sleep 10
done

# Start application
echo "=== Starting application ==="
systemctl daemon-reload
systemctl enable csye6225.service
systemctl restart csye6225.service

sleep 5
systemctl status csye6225.service --no-pager

echo "=== User Data Complete ==="
date