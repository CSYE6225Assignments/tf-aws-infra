#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting User Data Script ==="

# Environment variables from Terraform
export DB_HOST="${db_hostname}"
export DB_PORT="${db_port}"
export DB_NAME="${db_name}"
export DB_USER="${db_username}"
export DB_PASSWORD="${db_password}"
export S3_BUCKET_NAME="${s3_bucket_name}"
export AWS_REGION="${aws_region}"

# Create application.properties with RDS configuration
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

# Wait for RDS to be available (optional but recommended)
echo "Waiting for database to be ready..."
for i in {1..30}; do
  if mysqladmin ping -h "${db_hostname}" -u "${db_username}" -p"${db_password}" --silent 2>/dev/null; then
    echo "Database is ready!"
    break
  fi
  echo "Waiting for database... attempt $i/30"
  sleep 10
done

# Restart application service
systemctl daemon-reload
systemctl enable csye6225.service
systemctl restart csye6225.service

echo "=== User Data Script Complete ==="