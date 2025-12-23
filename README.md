# Cloud-Native Infrastructure (Terraform on AWS)

## Overview

This repository defines the **complete AWS infrastructure** for a cloud-native, multi-tier web application using **Terraform**. The infrastructure is designed to be **secure, scalable, reproducible, and environment-aware**, following Infrastructure as Code (IaC) best practices.

It supports a **Spring Boot REST API** deployed on EC2 instances built from **custom Packer AMIs**, backed by **Amazon RDS (MySQL)** for persistence and **Amazon S3** for object storage. High availability and scalability are achieved using an **Application Load Balancer (ALB)** and **Auto Scaling Groups (ASG)**.

This repository is intentionally focused **only on infrastructure concerns** and is decoupled from application and serverless logic.

---

## System Context & Repository Relationships

This project is part of a three-repository cloud-native system:

| Repository                                | Responsibility                                         |
| ----------------------------------------- | ------------------------------------------------------ |
| Web Application Repository                | Spring Boot REST API and business logic                |
| **Infrastructure Repository (this repo)** | AWS networking, compute, storage, and security         |
| Serverless Repository                     | Asynchronous workflows (email verification via Lambda) |

### Related Repositories

* **Web Application (Spring Boot API)**
  [https://github.com/CSYE6225Assignments/webapp](https://github.com/CSYE6225Assignments/webapp)

* **Infrastructure (Terraform on AWS)**
  [https://github.com/CSYE6225Assignments/tf-aws-infra](https://github.com/CSYE6225Assignments/tf-aws-infra)

* **Serverless (Lambda Email Verification)**
  [https://github.com/CSYE6225Assignments/serverless](https://github.com/CSYE6225Assignments/serverless)

---

## Why This Repository Exists

In production systems:

* Infrastructure must be **versioned, auditable, and reproducible**
* Servers should be **immutable**, not configured manually
* Application and infrastructure lifecycles must be independent

This repository exists to:

* Provision AWS infrastructure using Terraform
* Enable consistent environment creation (dev/demo/prod)
* Support immutable deployments using pre-built AMIs
* Centralize security, networking, and observability configuration

No application code or serverless logic exists in this repository.

---

## High-Level Architecture

### End-to-End Flow

```
User / Client
     │
     ▼
Route53 (Optional DNS)
     │
     ▼
Application Load Balancer (HTTP/HTTPS)
     │
     ▼
Target Group (Health check: /healthz)
     │
     ▼
Auto Scaling Group (3–5 EC2 instances)
     │
     ├── Amazon RDS (MySQL, private subnets)
     ├── Amazon S3 (image storage)
     └── Amazon SNS (publish verification events)

Logs & Metrics → Amazon CloudWatch
```

---

## Core Infrastructure Components

### 1. VPC & Networking

The infrastructure is deployed inside a **dedicated VPC per environment** (dev/demo/prod) to ensure isolation and predictable networking.

**VPC Configuration**

* Custom CIDR block (configurable via `.tfvars`)
* DNS resolution and DNS hostnames enabled
* Tagged consistently for cost tracking and ownership

**Subnets**

* **Public Subnets (Multi‑AZ):**

  * One public subnet per availability zone
  * Used by Application Load Balancer and EC2 instances
  * Auto‑assign public IPv4 enabled

* **Private Subnets (Multi‑AZ):**

  * One private subnet per availability zone
  * Used exclusively by Amazon RDS
  * No public IP assignment

**Routing**

* **Internet Gateway** attached to the VPC
* **Public Route Table**:

  * Route `0.0.0.0/0 → Internet Gateway`
  * Associated with all public subnets
* **Private Route Table**:

  * No internet routes (VPC‑local only)
  * Associated with all private subnets

This design ensures that **only the load balancer and application layer are internet‑reachable**, while the database remains fully isolated.

---

### 2. Load Balancing & Traffic Control

**Application Load Balancer (ALB)**

* Internet‑facing ALB
* Listens on HTTP (80) and optionally HTTPS (443)
* Routes traffic to a target group on application port (8080)
* Health checks configured on `/healthz`

**Target Group**

* Instance target type
* Health check path: `/healthz`
* Used by Auto Scaling Group for registration and deregistration

All external traffic flows **only through the ALB**. Direct access to EC2 instances is restricted by security groups.

---

### 3. Compute Layer (EC2 + Auto Scaling)

**Launch Template**

* Uses a **custom AMI built with Packer**
* Defines instance type, root volume, IAM profile, and user‑data
* Enforces IMDSv2 for metadata access

**Auto Scaling Group (ASG)**

* Runs across multiple availability zones
* Minimum, maximum, and desired capacity configurable
* Health check type: ELB
* Grace period to allow application startup

**Scaling Policies**

* CPU‑based scale‑up and scale‑down policies
* CloudWatch alarms trigger scaling actions
* Cooldown periods prevent scaling thrash

This ensures **high availability**, **self‑healing**, and **elastic capacity**.

---

### 4. Database Layer (Amazon RDS)

**RDS MySQL Configuration**

* Engine: MySQL 8.x
* Deployed in **private subnets only**
* No public accessibility
* Encrypted storage using AWS‑managed KMS keys

**Subnet Group**

* Includes all private subnets across AZs
* Enables future Multi‑AZ deployments without redesign

**Parameter Group**

* Custom parameter group (not default)
* UTF‑8 character set configuration
* Tuned connection limits

**Backups & Logs**

* Automated backups enabled
* CloudWatch logs: error, general, slow query

---

### 5. Object Storage (Amazon S3)

**S3 Bucket Design**

* Private bucket with globally unique name
* Public access fully blocked
* Server‑side encryption enabled
* Versioning enabled
* Lifecycle rule transitions objects to lower‑cost storage

**Usage**

* Stores user‑uploaded product images
* Accessed only via IAM role attached to EC2 instances

---

### 6. Security Groups (Network Firewall Rules)

**Load Balancer Security Group**

* Inbound:

  * 80 (HTTP) from `0.0.0.0/0`
  * 443 (HTTPS) from `0.0.0.0/0`
* Outbound:

  * All traffic allowed

**Application Security Group**

* Inbound:

  * 8080 from Load Balancer security group only
  * 22 (SSH) from restricted CIDR (optional, configurable)
* Outbound:

  * All traffic allowed

**Database Security Group**

* Inbound:

  * 3306 from Application security group only
* Outbound:

  * All traffic allowed

No database ports are exposed publicly or via CIDR blocks.

---

### 7. IAM Roles & Permissions

**EC2 Instance Role**

* Attached to all application EC2 instances
* Uses IAM Instance Profile (no access keys on disk)

**Permissions Included**

* Amazon S3:

  * `GetObject`, `PutObject`, `DeleteObject`, `ListBucket` (scoped to image bucket)
* CloudWatch:

  * Log stream creation and log publishing
  * Custom metric publishing
* SNS:

  * Publish permissions for verification events
* EC2 metadata access via IMDSv2 only

**Security Principles**

* Least‑privilege policies
* Resource‑scoped permissions
* No hardcoded secrets or credentials

---

## Immutable Infrastructure Model

### Role of Packer

EC2 instances are launched from **custom AMIs** built using Packer in the web application repository.

The AMI contains:

* OS and runtime dependencies
* Application JAR
* CloudWatch Agent
* systemd service configuration

The AMI does **not** contain:

* Environment-specific configuration
* Secrets or credentials

### Runtime Configuration

At instance launch, **Terraform user-data scripts**:

1. Fetch database credentials from Terraform-generated outputs
2. Generate `application.properties`
3. Configure CloudWatch Agent
4. Wait for database readiness
5. Start the application service

This allows the same AMI to be reused across environments.

---

## Terraform Workflow

### Prerequisites

* Terraform v1.0+
* AWS CLI configured with environment profiles
* Custom AMI ID built via Packer

### Common Commands

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan  -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Destroy

```bash
terraform destroy -var-file=dev.tfvars
```

---

## Environment Strategy

* Separate `.tfvars` files per environment
* Same Terraform code reused for dev/demo/prod
* Optional separate state files or workspaces

---

## Observability

* EC2 and application logs streamed to **CloudWatch Logs**
* Metrics published to **CloudWatch Metrics**
* ALB health checks and ASG scaling driven by CloudWatch alarms

---

## Security Best Practices

* Private RDS with no public access
* Encrypted data at rest (RDS, EBS, S3)
* IAM roles with least privilege
* No credentials stored in code or AMIs
* Security groups scoped by source group, not CIDR

---

## CI Integration

* Terraform formatting and validation run on pull requests
* Prevents invalid or unsafe infrastructure changes
* Apply operations performed manually

---

## Summary

This repository provides a **production-ready AWS infrastructure** using Terraform with:

* High availability and auto scaling
* Secure networking and data isolation
* Immutable deployment model
* Clear separation from application and serverless layers

Together with the web application and serverless repositories, it forms a **complete cloud-native system** following real-world engineering practices.
