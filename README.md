# Terraform AWS Infrastructure: Multi‑Tier Web App (Spring Boot + RDS + S3)

This repository automates a complete AWS cloud setup with **Terraform** for a multi‑tier web application. It provisions **networking, compute, database, storage, and security** with Infrastructure as Code principles. All configurations are parameterized via **.tfvars** (no hardcoded values).

The infrastructure supports a Spring Boot REST API with:
- **Networking:** VPC with public/private subnets across multiple AZs
- **Compute:** EC2 instances from **custom Packer AMIs** with IAM roles
- **Database:** RDS MySQL in **private subnets**
- **Storage:** S3 for user‑uploaded images
- **Security:** Security Groups, IAM roles/policies, encryption at rest

---

## Table of Contents
- [Overview](#overview)
- [Features](#features)
    - [Networking](#networking)
    - [Compute & Application](#compute--application)
    - [Database (RDS)](#database-rds)
    - [Storage (S3)](#storage-s3)
    - [Security & IAM](#security--iam)
    - [Infrastructure as Code](#infrastructure-as-code)
- [Files Included](#files-included)
- [Prerequisites](#prerequisites)
- [AWS CLI Setup](#aws-cli-setup)
- [Quick Start](#quick-start)
- [Infrastructure Architecture](#infrastructure-architecture)
- [Detailed Component Documentation](#detailed-component-documentation)
    - [1. VPC and Networking](#1-vpc-and-networking)
    - [2. S3 Bucket for Images](#2-s3-bucket-for-images)
    - [3. RDS Database](#3-rds-database)
    - [4. Security Groups](#4-security-groups)
    - [5. IAM Role and Policies](#5-iam-role-and-policies)
    - [6. EC2 User Data](#6-ec2-user-data)
- [Terraform Commands](#terraform-commands)
- [Verify Infrastructure](#verify-infrastructure)
- [Test Application Deployment](#test-application-deployment)
- [SSH to Instance (Optional)](#ssh-to-instance-optional)
- [Destroy Infrastructure](#destroy-infrastructure)
- [Variables Reference](#variables-reference)
- [Outputs Reference](#outputs-reference)
- [Assignment Requirements Compliance](#assignment-requirements-compliance)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)
- [Continuous Integration](#continuous-integration)
- [Multi‑Environment Deployment](#multi-environment-deployment)
- [Security Best Practices](#security-best-practices)
- [State Management](#state-management)
- [Monitoring and Logging](#monitoring-and-logging)
- [Key Design Decisions](#key-design-decisions)
- [Development Workflow](#development-workflow)
- [Full Architecture Diagrams](#full-architecture-diagrams)
- [Resource Dependencies](#resource-dependencies)
- [Verification Script](#verification-script)

---

## Overview

This project automates the complete AWS cloud infrastructure setup using **Terraform** for a multi‑tier web application. It provisions networking, compute, database, storage, and security resources. The setup is **environment‑aware** (dev/demo/prod), parameterized using `.tfvars`, and avoids hardcoded values.

---

## Features

### Networking
- **VPC per environment** (`dev`, `demo`, `prod`) with custom CIDR blocks
- **3 Public Subnets** across **3 AZs**
- **3 Private Subnets** across **3 AZs** for RDS
- **Internet Gateway** attached for public internet access
- **Route Tables:** Separate public/private
    - Public route: `0.0.0.0/0 → IGW`
- **Dynamic AZ Distribution:** Round‑robin subnet allocation
- **Multi‑Region Support:** Works in any AWS region

### Compute & Application
- **EC2** launched from **custom Packer‑built AMI**
- **IAM Instance Profile** for S3 access (no hardcoded creds)
- **User Data Script** configures app at boot with RDS & S3 details
- **Application SG:** ports **22, 80, 443, 8080**
- **systemd auto‑start** (no manual intervention)
- **25GB** gp2/gp3 root volume, delete‑on‑termination
- **No termination protection** for easy cleanup
- Optional **SSH key** (instances can run without SSH)
- **Public IP** for external access

### Database (RDS)
- **RDS MySQL 8.0** (managed)
- **Private Subnets only** (no public access)
- **Custom Parameter Group** (not default)
- **DB Subnet Group** across multiple AZs
- **DB SG:** Port 3306 from **Application SG only**
- **Encrypted storage**, **7‑day backups**, CloudWatch Logs (error/general/slow)
- **Single‑AZ** by default (configurable Multi‑AZ)

### Storage (S3)
- **Private S3 bucket** with **UUID‑based** name
- **Default encryption:** AES256 (SSE‑S3)
- **Versioning enabled**
- **Lifecycle policy:** STANDARD → STANDARD_IA after 30 days
- **Public access blocked** (all settings)
- **Force destroy** for cleanup

### Security & IAM
- **Application SG** + **Database SG** (3306 only from App SG)
- **IAM Role** for EC2 with **scoped S3 policy**
- **Instance Profile** attached (automatic credential management)
- **No hardcoded credentials**
- **Least privilege** policies

### Infrastructure as Code
- **Parameterized** via `.tfvars`
- **Auto‑generated secrets** (RDS password)
- **Idempotent** applies, safe destroys
- **Input validation** & **comprehensive tagging**
- **Explicit dependencies** (`depends_on`)

---

## Files Included
```
├── main.tf                           # VPC, subnets, IGW, route tables, EC2
├── variables.tf                      # All variable definitions with validation
├── outputs.tf                        # Output values (IPs, endpoints, ARNs)
├── s3.tf                             # S3 bucket for image storage
├── rds.tf                            # RDS instance, parameter group, subnet group
├── security-groups.tf                # Application and Database security groups
├── iam.tf                            # IAM roles, policies, instance profile
├── user-data.sh                      # EC2 user data script template
├── dev.tfvars                        # DEV environment config (gitignored)
├── demo.tfvars                       # DEMO environment config (gitignored)
└── .github/workflows/
    └── terraform-ci.yml              # CI workflow for validation
```

---

## Prerequisites
- **AWS CLI** configured with `dev` and `demo` profiles
- **Terraform v1.0+**
- **Packer‑built AMI** from the webapp repository
- **EC2 Key Pair** imported to AWS (optional, for SSH)
- **jq** (for JSON querying in verification commands)

---

## AWS CLI Setup
```bash
# Configure profiles
aws configure --profile dev
aws configure --profile demo

# Verify authentication
aws sts get-caller-identity --profile dev
aws sts get-caller-identity --profile demo

# Test basic access
aws ec2 describe-vpcs --profile dev
aws s3 ls --profile demo
```

---

## Quick Start

### 1) Get Your Custom AMI ID
```bash
aws ec2 describe-images \
  --owners self \
  --profile dev \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name,CreationDate]' \
  --output table
```
Copy the AMI ID (e.g., `ami-0123456789abcdef0`).

### 2) Create Configuration File
Create **`dev.tfvars`** (do **not** commit):
```hcl
# Network Configuration
region       = "us-east-1"
profile      = "dev"
vpc_name     = "csye6225-dev"
environment  = "dev"
project_name = "csye6225"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

# EC2 Configuration
ami_id        = "ami-0123456789abcdef0"  # YOUR AMI ID
instance_type = "t2.micro"
key_name      = null  # Or "your-key-name" if you want SSH access
app_port      = 8080

# RDS Configuration
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_name              = "csye6225"
db_username          = "csye6225"
# db_password is auto-generated by Terraform
db_multi_az          = false
```

### 3) Deploy Infrastructure
```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
# Type 'yes' when prompted (RDS may take 10–15 minutes)
```

### 4) Get Outputs and Test
```bash
terraform output

terraform output instance_public_ip
terraform output s3_bucket_name
terraform output rds_endpoint
terraform output application_url
terraform output health_check_url

# Sensitive:
terraform output rds_password
```

### 5) Verify Application
```bash
sleep 180   # wait 2–3 minutes for app to start
curl http://$(terraform output -raw instance_public_ip):8080/healthz
# Expected: HTTP 200 OK
```

---

## Infrastructure Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Internet Gateway                         │  │
│  └─────────────────────┬────────────────────────────────────┘  │
│                        │                                        │
│  ┌─────────────────────┴────────────────────────────────────┐  │
│  │              Public Route Table                          │  │
│  │              Route: 0.0.0.0/0 → IGW                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Public Subnets (3 AZs)                           │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │  10.0.1.0/24 (az-a) ┌─────────────────┐                  │ │
│  │  10.0.2.0/24 (az-b) │  EC2 Instance   │                  │ │
│  │  10.0.3.0/24 (az-c) │  - Public IP    │                  │ │
│  │                      │  - IAM Profile  │                  │ │
│  │                      │  - App SG       │                  │ │
│  │                      └─────────────────┘                  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │         Private Subnets (3 AZs)                          │ │
│  ├───────────────────────────────────────────────────────────┤ │
│  │  10.0.4.0/24 (az-a) ┌─────────────────┐                  │ │
│  │  10.0.5.0/24 (az-b) │  RDS MySQL      │                  │ │
│  │  10.0.6.0/24 (az-c) │  - Private only │                  │ │
│  │                      │  - DB SG        │                  │ │
│  │                      │  - Encrypted    │                  │ │
│  │                      └─────────────────┘                  │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    S3 Bucket (Global)                           │
│  csye6225-images-{uuid}                                         │
│  - Encrypted (AES256)                                           │
│  - Versioned                                                    │
│  - Private (no public access)                                   │
│  - Lifecycle: STANDARD → STANDARD_IA (30 days)                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         Security                                │
├─────────────────────────────────────────────────────────────────┤
│  Application SG         │  Database SG                          │
│  - 22 (SSH)             │  - 3306 from App SG only              │
│  - 80 (HTTP)            │  - No public access                   │
│  - 443 (HTTPS)          │                                       │
│  - 8080 (App)           │                                       │
│                                                                 │
│  IAM Role (EC2)                                                 │
│  - s3:PutObject, GetObject, DeleteObject                        │
│  - s3:ListBucket                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Component Documentation

### 1. VPC and Networking
**VPC Configuration**
- CIDR block (default `10.0.0.0/16`), **DNS hostnames/support enabled**

**Subnets**
- **Public:** auto‑assign public IP enabled
- **Private:** no public IP
- **Distribution:** round‑robin across 3 AZs
- IPv4 addressing with proper CIDR allocation

**Routing**
- Public route table → `0.0.0.0/0` via IGW
- Private route table → local VPC only
- Associations for all subnets

### 2. S3 Bucket for Images
**Resource:** `aws_s3_bucket.images`
- **Name:** `csye6225-images-{uuid}` for global uniqueness
- **force_destroy:** true (cleanup friendly)
- **Encryption:** SSE‑S3 (AES256)
- **Versioning:** enabled
- **Public Access Block:** all settings enabled
- **Lifecycle:** STANDARD → STANDARD_IA after 30 days

**Storage Classes**
- Day 0‑29: **STANDARD**
- Day 30+: **STANDARD_IA**

**Cleanup**
```bash
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive --profile dev
# Or let force_destroy handle it automatically
terraform destroy -var-file="dev.tfvars"
```

### 3. RDS Database
**Resource:** `aws_db_instance.main`
- MySQL **8.0.35** (configurable), class `db.t3.micro` (example)
- Storage: **20GB gp3**
- Identifier/db/username: `csye6225`
- **Password auto‑generated** (Terraform)
- **Subnet Group:** private subnets across 3 AZs
- **DB SG:** only from App SG (port 3306)
- **Public Accessibility:** disabled
- **Backups:** 7 days; window 03:00–04:00 UTC
- **Maintenance:** Monday 04:00–05:00 UTC
- **Logs:** error/general/slow to CloudWatch
- **Custom Parameter Group** (family: mysql8.0)
    - `character_set_server=utf8mb4`
    - `collation_server=utf8mb4_unicode_ci`
    - `max_connections=100`
- **Multi‑AZ:** disabled by default (enable via variable)

### 4. Security Groups
**Application SG (`aws_security_group.application`)**
- Ingress: 22, 80, 443, 8080 from `0.0.0.0/0`
- Egress: all to `0.0.0.0/0`

**Database SG (`aws_security_group.database`)**
- Ingress: **3306 from Application SG only** (no CIDR)
```hcl
resource "aws_security_group_rule" "db_ingress_from_app" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.database.id
  source_security_group_id = aws_security_group.application.id
}
```
- Egress: all to `0.0.0.0/0`

### 5. IAM Role and Policies
**EC2 Instance Role** — `aws_iam_role.ec2_instance_role`
- Trust: `ec2.amazonaws.com`

**S3 Access Policy** — `aws_iam_policy.s3_access_policy`
- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:ListBucket`
- **Resource scope:** images bucket and its objects only

**Instance Profile** — `aws_iam_instance_profile.ec2_instance_profile`
- Attaches role to EC2 (automatic credentials via metadata)

### 6. EC2 User Data
**`user-data.sh`** (template) performs:
- Waits for network ready
- Installs `netcat` for DB checks
- Creates `/opt/csye6225/application.properties` with:
    - RDS endpoint & credentials
    - S3 bucket name & region
    - `storage.type=s3`
- Sets secure permissions (640, owned by `csye6225`)
- Waits for DB reachability (30×, 10s)
- Starts `csye6225` systemd service
- Logs to `/var/log/user-data.log`

**Variables passed from Terraform:**
- `db_hostname`, `db_port=3306`, `db_name`, `db_username`, `db_password`
- `s3_bucket_name`, `aws_region`

**Generated application config:**
```properties
spring.datasource.url=jdbc:mysql://csye6225.xxxxx.rds.amazonaws.com:3306/csye6225?useSSL=false&serverTimezone=UTC
spring.datasource.username=csye6245
spring.datasource.password=auto-generated-password
aws.s3.bucket-name=csye6225-images-xxxxx
aws.region=us-east-1
storage.type=s3
```

---

## Terraform Commands

**Initialize and Validate**
```bash
terraform init
terraform fmt -check -recursive
terraform fmt -recursive
terraform validate
```

**Deploy to Different Environments**
```bash
# DEV
terraform apply -var-file="dev.tfvars"

# DEMO
terraform apply -var-file="demo.tfvars"

# Using separate state files (recommended)
terraform apply -var-file="dev.tfvars"  -state="terraform-dev.tfstate"
terraform apply -var-file="demo.tfvars" -state="terraform-demo.tfstate"
```

---

## Verify Infrastructure

### VPC & Networking
```bash
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=false \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' \
  --profile dev

aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw public_route_table_id) \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' \
  --profile dev

aws ec2 describe-subnets \
  --subnet-ids $(terraform output -json public_subnet_ids | jq -r '.[]' | xargs) \
  --query 'Subnets[].AvailabilityZone' \
  --profile dev | jq 'unique | length'  # Expected: 3
```

### Security Groups
```bash
# App SG should show 22, 80, 443, 8080
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw application_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort]' \
  --output table \
  --profile dev

# DB SG should only allow from App SG (no CIDR)
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw database_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[0]' \
  --profile dev
```

### S3 Bucket
```bash
aws s3 ls --profile dev | grep csye6225-images

aws s3api get-bucket-encryption \
  --bucket $(terraform output -raw s3_bucket_name) \
  --profile dev

aws s3api get-bucket-versioning \
  --bucket $(terraform output -raw s3_bucket_name) \
  --profile dev

aws s3api get-bucket-lifecycle-configuration \
  --bucket $(terraform output -raw s3_bucket_name) \
  --profile dev

aws s3api get-public-access-block \
  --bucket $(terraform output -raw s3_bucket_name) \
  --profile dev
```

### RDS Database
```bash
aws rds describe-db-instances \
  --db-instance-identifier csye6225 \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,PubliclyAccessible]' \
  --output table \
  --profile dev

aws rds describe-db-instances \
  --db-instance-identifier csye6225 \
  --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' \
  --output text \
  --profile dev

aws rds describe-db-instances \
  --db-instance-identifier csye6225 \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' \
  --profile dev
```

### IAM Role
```bash
aws iam get-role \
  --role-name $(terraform output -raw iam_role_name) \
  --profile dev

aws iam list-attached-role-policies \
  --role-name $(terraform output -raw iam_role_name) \
  --profile dev
```

### EC2 Instance
```bash
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table \
  --profile dev

aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text \
  --profile dev
```

---

## Test Application Deployment
```bash
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Health check
curl -v http://$INSTANCE_IP:8080/healthz

# Create user
curl -X POST http://$INSTANCE_IP:8080/v1/user \
  -H "Content-Type: application/json" \
  -d '{
    "username": "terraform@test.com",
    "password": "password123",
    "first_name": "Terraform",
    "last_name": "User"
  }'

# Create product
curl -X POST http://$INSTANCE_IP:8080/v1/product \
  -u terraform@test.com:password123 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "Testing S3 upload",
    "sku": "TEST-001",
    "manufacturer": "TestCorp",
    "quantity": 10
  }'

# Upload an image
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" | base64 -d > test.png
curl -X POST http://$INSTANCE_IP:8080/v1/product/1/image \
  -u terraform@test.com:password123 \
  -F "file=@test.png"

# Verify in S3
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/ --recursive --profile dev
# Expected: user_1/product_1/{uuid}.png
```

---

## SSH to Instance (Optional)
```bash
ssh -i /path/to/your-key.pem ubuntu@$(terraform output -raw instance_public_ip)
sudo systemctl status csye6225
sudo journalctl -u csye6225 -f
sudo cat /var/log/user-data.log
cat /opt/csye6225/application.properties | grep datasource.url
nc -zv $(cat /opt/csye6225/application.properties | grep datasource.url | cut -d'/' -f3 | cut -d':' -f1) 3306
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
aws s3 ls s3://$(cat /opt/csye6225/application.properties | grep s3.bucket-name | cut -d'=' -f2)/
```

---

## Destroy Infrastructure
```bash
terraform plan -destroy -var-file="dev.tfvars"
terraform destroy -var-file="dev.tfvars"

# With separate state
terraform destroy -var-file="dev.tfvars"  -state="terraform-dev.tfstate"
terraform destroy -var-file="demo.tfvars" -state="terraform-demo.tfstate"
# S3 bucket is emptied & deleted automatically (force_destroy = true)
```

---

## Variables Reference

### Required Variables
| Variable | Type | Description | Example |
|---|---|---|---|
| region | string | AWS region | `us-east-1` |
| profile | string | AWS CLI profile | `dev` |
| vpc_name | string | Unique VPC name | `csye6225-dev` |
| environment | string | Environment | `dev` / `demo` / `prod` |
| vpc_cidr | string | VPC CIDR | `10.0.0.0/16` |
| public_subnet_cidrs | list(string) | Public subnet CIDRs | `["10.0.1.0/24", ...]` |
| private_subnet_cidrs | list(string) | Private subnet CIDRs | `["10.0.4.0/24", ...]` |
| ami_id | string | Packer AMI ID | `ami-0123456789abcdef0` |

### Optional Variables
| Variable | Type | Default | Description |
|---|---|---|---|
| instance_type | string | `t2.micro` | EC2 instance type |
| key_name | string | `null` | SSH key pair name |
| app_port | number | `8080` | Application port |
| db_instance_class | string | `db.t3.micro` | RDS class |
| db_allocated_storage | number | `20` | RDS storage (GB) |
| db_name | string | `csye6225` | DB name |
| db_username | string | `csye6225` | DB username |
| db_multi_az | bool | `false` | Multi‑AZ deployment |
| root_volume_size | number | `25` | EC2 root volume size |
| root_volume_type | string | `gp2` | EC2 volume type |
| max_azs | number | `0` | Max AZs to use (`0 = all`) |

> **Note:** `db_password` is auto‑generated (no need in tfvars).

---

## Outputs Reference

### Networking
```bash
terraform output vpc_id
terraform output vpc_cidr
terraform output internet_gateway_id
terraform output public_subnet_ids
terraform output private_subnet_ids
terraform output availability_zones_info
```

### Compute
```bash
terraform output instance_id
terraform output instance_public_ip
terraform output instance_public_dns
terraform output instance_private_ip
terraform output application_url
terraform output health_check_url
```

### Database
```bash
terraform output rds_endpoint
terraform output rds_hostname
terraform output rds_port
terraform output rds_database_name
terraform output rds_password   # sensitive
```

### Storage
```bash
terraform output s3_bucket_name
terraform output s3_bucket_arn
terraform output s3_bucket_region
```

### Security
```bash
terraform output application_security_group_id
terraform output database_security_group_id
terraform output iam_role_name
terraform output iam_instance_profile_name
```

---

## Assignment Requirements Compliance

### Infrastructure
✅ Terraform **VPC** (non‑default)  
✅ **3 Public** and **3 Private** subnets across 3 AZs  
✅ **Internet Gateway** + public route `0.0.0.0/0`  
✅ App SG: **22/80/443/8080** open  
✅ DB port **3306 NOT** exposed externally  
✅ **Custom AMI** from Packer  
✅ **25GB** root volume, delete on termination  
✅ **No termination protection**  
✅ systemd **auto‑start** via user‑data

### Database
✅ RDS in **private** subnets  
✅ SG type **EC2** (not DB type)  
✅ **3306** only from App SG (no CIDRs)  
✅ **Custom param group** (not default)  
✅ Identifier/username/db name: `csye6225`  
✅ Single‑AZ (configurable)  
✅ User‑data passes DB creds to app

### Storage
✅ Private S3 bucket (UUID name)  
✅ **force_destroy** enabled  
✅ Default encryption (AES256)  
✅ Lifecycle: STANDARD → STANDARD_IA (30d)  
✅ Versioning enabled  
✅ Public access blocked

### IAM
✅ IAM role + instance profile for EC2  
✅ S3 policy scoped to bucket  
✅ No hardcoded creds  
✅ Least privilege

---

## Cost Estimation

**Always running (monthly):**
- VPC/Subnets/IGW/Route Tables/SG/IAM — **FREE**
- EC2 `t2.micro` — ~**$8.50**
- EBS 25GB `gp2` — ~**$2.50**
- RDS `db.t3.micro` (single‑AZ) — ~**$13**
- RDS storage 20GB `gp3` — ~**$2.30**
- S3 STANDARD — **$0.023/GB**
- S3 STANDARD_IA — **$0.0125/GB**

**Example total:** ~**$27–30/mo** (minimal usage)

**Save costs:**
```bash
terraform destroy -var-file="dev.tfvars"
```
Residual: AMI storage ~**$0.80/mo**; empty S3 ~**$0**.

---

## Troubleshooting

### Terraform
- **Invalid credentials:**
  ```bash
  aws sts get-caller-identity --profile dev
  ```
- **VPC name in use:** change `vpc_name` in tfvars
- **AMI not found:** ensure AMI exists in region
- **RDS version unavailable:** list supported versions
- **Unsupported AZ:** list available AZs
- **State lock:** `terraform force-unlock <LOCK_ID>`

### Application
- **Health check 503:** wait 3–5 mins, check logs via `journalctl`
- **DB connectivity:** check DB SG from App SG, RDS status, `nc -zv <endpoint> 3306`
- **S3 upload 500:** verify IAM profile, bucket name, instance metadata creds
- **Port access:** verify App SG has `8080` ingress
- **DB password:** `terraform output -raw rds_password`

---

## Continuous Integration

**`.github/workflows/terraform-ci.yml`** (PRs to `main`):
- ✅ `terraform fmt -check`
- ✅ `terraform validate`
- ✅ Optional: `tfsec`, `checkov`
- ✅ Comments on PR; blocks merge on failure

**Branch protection:** require CI checks, PR reviews, no force pushes.

---

## Multi‑Environment Deployment

**Separate state files (recommended):**
```bash
terraform apply  -var-file="dev.tfvars"  -state="terraform-dev.tfstate"
terraform destroy -var-file="dev.tfvars"  -state="terraform-dev.tfstate"

terraform apply  -var-file="demo.tfvars" -state="terraform-demo.tfstate"
terraform destroy -var-file="demo.tfvars" -state="terraform-demo.tfstate"
```

**Workspaces:**
```bash
terraform workspace new dev
terraform workspace new demo
terraform workspace select dev   && terraform apply -var-file="dev.tfvars"
terraform workspace select demo  && terraform apply -var-file="demo.tfvars"
terraform workspace list
terraform workspace show
```

---

## Security Best Practices
- **Secrets:** RDS password auto‑generated; sensitive outputs; `.tfvars` gitignored
- **IAM:** role‑based access; least privilege; no access keys in app
- **Network:** RDS private; DB SG from App SG only; S3 public access blocked
- **Data:** RDS encrypted; S3 encryption + versioning; backups enabled
- **Runtime:** user‑data as root, app runs as `csye6225` user

---

## State Management

**Local state (default):** simple but not for teams.  
**Remote state (recommended):** S3 backend with DynamoDB locking.

Example `backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "csye6225/dev/terraform.tfstate"
    region         = "us-east-1"
    profile        = "dev"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

---

## Monitoring and Logging
- **RDS → CloudWatch:** error, general, slow query logs
- **App logs:** `journalctl -u csye6225 -f` (SSH) or via SSM Session Manager
- **User‑data logs:** `/var/log/user-data.log`

Examples:
```bash
aws logs tail /aws/rds/instance/csye6225/error --follow --profile dev
aws ssm start-session --target $(terraform output -raw instance_id) --profile dev  # if SSM enabled
```

---

## Key Design Decisions

### Security
- RDS **isolated** in private subnets; DB SG only from App SG
- **No hardcoded credentials**; S3 via IAM role
- **Encrypted storage**: RDS & S3
- **Minimal exposure**: only required ports open

### High Availability
- **Multi‑AZ subnets**; DB subnet group enables future Multi‑AZ RDS
- **Auto‑recovery**: systemd app auto‑start
- **Dependencies**: `depends_on` for correct ordering

### Cost Optimization
- **Single‑AZ RDS** for dev/demo; enable Multi‑AZ for prod
- **gp3** storage for performance/cost
- **S3 lifecycle** to STANDARD_IA
- **Small instances** for dev; destroy when idle

### IaC Principles
- Fully automated; **idempotent**; **safe destroy**
- **Validation** on inputs; **comprehensive tagging**
- **Template user‑data** for dynamic app config

---

## Development Workflow
1. Update **.tf** files
2. `terraform fmt -recursive`
3. `terraform validate`
4. `terraform plan -var-file="dev.tfvars"`
5. Review plan
6. `terraform apply -var-file="dev.tfvars"`
7. Test application & AWS resources
8. Commit to feature branch
9. Open PR → CI validates
10. Merge after review

---

## Full Architecture Diagrams

### Complete Infrastructure
```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS Account (DEV/DEMO)                           │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                          │ │
│  │                                                               │ │
│  │  ┌────────────────────────────────────────────────────────┐  │ │
│  │  │  Public Subnets (3 AZs)                                │  │ │
│  │  │  ┌──────────────────────────────────────────────────┐  │  │ │
│  │  │  │  EC2 Instance (Public IP)                        │  │  │ │
│  │  │  │  - Custom AMI (Ubuntu + Java + App)              │  │  │ │
│  │  │  │  - IAM Instance Profile                          │  │  │ │
│  │  │  │  - Application Security Group                    │  │  │ │
│  │  │  │  - User Data: Configure app at boot              │  │  │ │
│  │  │  │  - Auto-start via systemd                        │  │  │ │
│  │  │  └──────────────────────────────────────────────────┘  │  │ │
│  │  │                        ↓                                │  │ │
│  │  │                 Connects to RDS (3306)                 │  │ │
│  │  │                 Uploads to S3 (via IAM)                │  │ │
│  │  └────────────────────────────────────────────────────────┘  │ │
│  │                                                               │ │
│  │  ┌────────────────────────────────────────────────────────┐  │ │
│  │  │  Private Subnets (3 AZs)                              │  │ │
│  │  │  ┌──────────────────────────────────────────────────┐  │  │ │
│  │  │  │  RDS MySQL 8.0 (Private)                         │  │  │ │
│  │  │  │  - No public access                              │  │  │ │
│  │  │  │  - Database Security Group                       │  │  │ │
│  │  │  │  - Custom Parameter Group                        │  │  │ │
│  │  │  │  - Encrypted storage (gp3)                       │  │  │ │
│  │  │  │  - Auto-generated password                       │  │  │ │
│  │  │  └──────────────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────────────┘  │ │
│  │                                                               │ │
│  │  Security Groups:                                             │ │
│  │  ┌───────────────────────────────────────────────────────┐   │ │
│  │  │  App SG: 22, 80, 443, 8080 ← 0.0.0.0/0               │   │ │
│  │  │  DB SG:  3306 ← App SG only (no CIDR blocks)         │   │ │
│  │  └───────────────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │         S3 Bucket (Region-specific, Global namespace)         │ │
│  │  csye6225-images-{uuid}                                       │ │
│  │  - Encryption: AES256                                         │ │
│  │  - Versioning: Enabled                                        │ │
│  │  - Public Access: Blocked                                     │ │
│  │  - Lifecycle: STANDARD → STANDARD_IA (30d)                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                     IAM Resources                             │ │
│  │  ┌─────────────────────────────────────────────────────────┐  │ │
│  │  │  EC2 Instance Role                                      │  │ │
│  │  │  └── S3 Access Policy (scoped to images bucket)        │  │ │
│  │  │      - s3:PutObject, GetObject, DeleteObject            │  │ │
│  │  │      - s3:ListBucket                                    │  │ │
│  │  └─────────────────────────────────────────────────────────┘  │ │
│  │  ┌─────────────────────────────────────────────────────────┐  │ │
│  │  │  EC2 Instance Profile                                   │  │ │
│  │  │  └── Attached to EC2 instance                           │  │ │
│  │  └─────────────────────────────────────────────────────────┘  │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Resource Dependencies
```
Internet Gateway
    ↓
VPC → Public Route Table → Public Subnets → EC2 Instance
                                                ↓
                                          IAM Instance Profile
                                                ↓
                                            S3 Bucket

VPC → Private Route Table → Private Subnets → DB Subnet Group
                                                    ↓
                                          RDS Parameter Group
                                                    ↓
                                              RDS Instance
                                                    ↑
                                          Database Security Group
                                                    ↑
                                          Application Security Group
```
**Terraform ensures:** IGW before routes, subnets before associations, RDS available before EC2 launches, S3 before IAM policy references, IAM instance profile before EC2 attachment.

---

## Verification Script
Create `infrastructure-verify.sh` and run it after `terraform apply`:
```bash
#!/bin/bash
echo "=== VPC and Networking ==="
terraform output vpc_id
terraform output vpc_cidr
terraform output public_subnet_ids
terraform output private_subnet_ids

echo "=== EC2 Instance ==="
terraform output instance_id
terraform output instance_public_ip
terraform output application_url

echo "=== RDS Database ==="
terraform output rds_endpoint
terraform output rds_database_name
echo "DB Password: $(terraform output -raw rds_password)"

echo "=== S3 Bucket ==="
terraform output s3_bucket_name
terraform output s3_bucket_arn

echo "=== Security ==="
terraform output application_security_group_id
terraform output database_security_group_id
terraform output iam_role_name

echo "=== Testing Application ==="
INSTANCE_IP=$(terraform output -raw instance_public_ip)
echo "Health Check:"
curl -s -o /dev/null -w "%{http_code}" http://$INSTANCE_IP:8080/healthz
echo ""

echo "=== Verifying S3 Access ==="
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/ --profile dev

echo "=== Verifying RDS Accessibility ==="
aws rds describe-db-instances \
  --db-instance-identifier csye6225 \
  --query 'DBInstances[0].[DBInstanceStatus,PubliclyAccessible]' \
  --profile dev

echo "=== Done ==="
```

---

