# AWS Infrastructure with Terraform

## Overview
This project automates the complete AWS infrastructure setup using Terraform, including networking (VPC, subnets, routing) and compute resources (EC2 instances with custom AMIs).

It creates:
- Virtual Private Cloud (VPC) with public and private subnets
- Internet Gateway and route tables
- Application security group with proper ingress/egress rules
- EC2 instances running the Spring Boot application from custom AMIs built with Packer
- All configurations are parameterized using `.tfvars` files—no hardcoded values

## Features

### Networking
- One VPC per environment (dev, demo, etc.)
- 3 Public and 3 Private subnets distributed across 3 Availability Zones
- Internet Gateway attached to VPC
- Public route to Internet Gateway (0.0.0.0/0)
- Separate public and private route tables
- Dynamic AZ distribution (round-robin logic)
- Works across multiple regions without conflict

### Compute & Security
- **Application Security Group** with ports 22, 80, 443, and 8080 (application port)
- **Database port (3306) NOT exposed** - MariaDB accessible only from localhost
- **EC2 instances** launched from custom Packer-built AMIs
- **Auto-start application** via systemd (no SSH needed)
- **25GB GP2 root volume** with delete-on-termination enabled
- **No termination protection** for easy cleanup
- **Optional SSH key** (instances can run without SSH access)
- **Explicit public IP assignment** for reliable connectivity

### CI/CD Integration
- GitHub Actions CI for terraform fmt and validate checks
- Automated AMI builds integrated with infrastructure deployment
- Branch protection ensures code quality

## Files Included
```
├── main.tf                           # VPC, subnets, security groups, EC2
├── variables.tf                      # All variable definitions
├── outputs.tf                        # Output values (IPs, IDs, URLs)
├── dev.tfvars                        # DEV environment config
├── demo.tfvars                       # DEMO environment config
└── .github/workflows/
    └── terraform-ci.yml              # CI/CD workflow
```

## Prerequisites

- **AWS CLI** configured with `dev` and `demo` profiles
- **Terraform** v1.0+
- **Packer-built AMI** (see main README for Packer setup)
- **EC2 Key Pair** imported to AWS (optional, for SSH access)
- **jq** (for JSON query verification)

## AWS CLI Setup
```bash
# Configure profiles
aws configure --profile dev
aws configure --profile demo

# Verify authentication
aws sts get-caller-identity --profile dev
aws sts get-caller-identity --profile demo
```

## Quick Start

### 1. Get Your Custom AMI ID
```bash
# Get latest AMI from Packer builds
aws ec2 describe-images \
  --owners self \
  --profile dev \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name]' \
  --output table
```

### 2. Update Configuration

Edit `dev.tfvars` with your AMI ID:
```hcl
ami_id = "ami-XXXXXXXXXXXXX"  # Replace with your AMI ID
```

### 3. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Format files
terraform fmt -recursive

# Validate configuration
terraform validate

# Preview changes
terraform plan -var-file="dev.tfvars"

# Apply infrastructure
terraform apply -var-file="dev.tfvars"
# Type 'yes' when prompted
```

### 4. Access Your Application
```bash
# Get instance public IP
terraform output instance_public_ip

# Wait 60-90 seconds for application to auto-start
sleep 90

# Test health endpoint
curl http://$(terraform output -raw instance_public_ip):8080/healthz
```

## Terraform Commands

### Initialize and Validate
```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

### Deploy to Different Environments
```bash
# DEV environment
terraform apply -var-file="dev.tfvars"

# DEMO environment  
terraform apply -var-file="demo.tfvars"

# Using separate state files
terraform apply -var-file="dev.tfvars" -state="terraform-dev.tfstate"
terraform apply -var-file="demo.tfvars" -state="terraform-demo.tfstate"
```

### Verify Infrastructure
```bash
# Check VPCs (should NOT be default VPC)
aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=false \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}'

# Verify public route has Internet Gateway
aws ec2 describe-route-tables \
  --route-table-ids $(terraform output -raw public_route_table_id) \
  --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Check subnet distribution across 3 AZs
aws ec2 describe-subnets \
  --subnet-ids $(terraform output -json public_subnet_ids | jq -r '.[]' | xargs) \
  --query 'Subnets[].AvailabilityZone' | jq 'unique | length'

# Verify security group rules (should show 22, 80, 443, 8080 - NO 3306)
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw application_security_group_id) \
  --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort]' \
  --output table

# Check instance is running
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress]' \
  --output table
```

### Test Application Deployment
```bash
# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Test health endpoint
curl -v http://$INSTANCE_IP:8080/healthz

# Test user creation
curl -X POST http://$INSTANCE_IP:8080/v1/user \
  -H "Content-Type: application/json" \
  -d '{
    "username": "terraform@test.com",
    "password": "password123",
    "first_name": "Terraform",
    "last_name": "User"
  }'

# Verify no SSH was needed - application auto-started!
```

### Destroy Infrastructure
```bash
# DEV environment
terraform destroy -var-file="dev.tfvars"

# DEMO environment
terraform destroy -var-file="demo.tfvars"

# With separate state files
terraform destroy -var-file="dev.tfvars" -state="terraform-dev.tfstate"
terraform destroy -var-file="demo.tfvars" -state="terraform-demo.tfstate"
```

## Infrastructure Architecture
```
VPC (10.0.0.0/16)
├── Internet Gateway
├── Public Subnets (3)
│   ├── 10.0.1.0/24 (us-east-1a)
│   ├── 10.0.2.0/24 (us-east-1b)
│   └── 10.0.3.0/24 (us-east-1c)
├── Private Subnets (3)
│   ├── 10.0.4.0/24 (us-east-1a)
│   ├── 10.0.5.0/24 (us-east-1b)
│   └── 10.0.6.0/24 (us-east-1c)
├── Public Route Table → Internet Gateway
├── Private Route Table (local only)
├── Application Security Group
│   ├── Ingress: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8080 (App)
│   └── Egress: All traffic
└── EC2 Instance
    ├── Custom AMI (Ubuntu 24.04 + Java + MariaDB + App)
    ├── 25GB GP2 root volume
    ├── Auto-assigned public IP
    ├── Application auto-starts via systemd
    └── Database runs locally (not exposed)
```

## Key Design Decisions

### Security
- **Database isolation**: Port 3306 NOT in security group - MariaDB only accessible from localhost
- **No hardcoded credentials**: All sensitive data in Terraform variables or AWS Secrets Manager
- **Optional SSH**: Key pair is optional (instances can run without SSH access)
- **Minimal attack surface**: Only necessary ports exposed

### High Availability
- **Multi-AZ deployment**: Resources distributed across 3 availability zones
- **Auto-recovery**: Application auto-starts on instance boot via systemd
- **Dependency management**: `depends_on` ensures networking is ready before instance launch

### Infrastructure as Code Best Practices
- **No manual steps**: Everything automated via Terraform
- **Idempotent**: Can run apply multiple times safely
- **Clean destruction**: `terraform destroy` removes all resources
- **Validation**: Input validation on all variables
- **Proper tagging**: Resources tagged with Environment, Project, Role

## Assignment Requirements Compliance

**EC2 in Terraform VPC** (not default VPC)  
**Application security group** with ports 22, 80, 443, and application port  
**Database port (3306) NOT exposed** externally  
**Custom AMI** built with Packer  
**25GB GP2 root volume**  
**Delete on termination** enabled  
**No termination protection**  
**Application auto-starts** (no SSH needed)  
**No git installed** in AMI  
**All APIs functional** without manual intervention  
**terraform apply** creates everything  
**terraform destroy** removes everything

## Troubleshooting

### Terraform Issues

**Invalid credentials:**
```bash
aws sts get-caller-identity --profile dev
```

**VPC already exists:**
```bash
# Change vpc_name in .tfvars file to make it unique
vpc_name = "csye6225-dev-v2"
```

**AMI not found:**
```bash
# Verify AMI exists and is accessible
aws ec2 describe-images --image-ids ami-XXXXX --profile dev
```

**Subnet/AZ issues:**
```bash
# List available AZs
aws ec2 describe-availability-zones --profile dev
```

### Application Issues

**Health check fails:**
```bash
# SSH into instance and check service
ssh -i ~/.ssh/csye6225-aws-key ubuntu@INSTANCE_IP
sudo systemctl status csye6225
sudo journalctl -u csye6225 -n 50
```

**Can't connect to instance:**
```bash
# Verify security group allows port 8080
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw application_security_group_id) \
  --profile dev
```

**Database connection issues:**
```bash
# Check MariaDB is running
ssh -i ~/.ssh/csye6225-aws-key ubuntu@INSTANCE_IP
sudo systemctl status mariadb
sudo mysql -e "SHOW DATABASES;"
```

## Continuous Integration

**GitHub Actions Workflow** (`.github/workflows/terraform-ci.yml`):
- Runs on pull requests to `main`
- Checks Terraform formatting
- Validates Terraform configuration
- Prevents merge if checks fail

**Branch Protection:**
- Requires CI checks to pass
- Requires pull request reviews
- No direct commits to main

## Multi-Environment Deployment

### DEV Environment
```bash
terraform apply -var-file="dev.tfvars" -state="terraform-dev.tfstate"
```

### DEMO Environment
```bash
terraform apply -var-file="demo.tfvars" -state="terraform-demo.tfstate"
```

### Managing Multiple Environments
```bash
# Using Terraform Workspaces
terraform workspace new dev
terraform workspace new demo

terraform workspace select dev
terraform apply -var-file="dev.tfvars"

terraform workspace select demo
terraform apply -var-file="demo.tfvars"

# List workspaces
terraform workspace list
```

## Outputs Reference

After `terraform apply`, you can access:
```bash
terraform output vpc_id                          # VPC identifier
terraform output instance_public_ip              # EC2 public IP
terraform output health_check_url                # Direct health check URL
terraform output application_security_group_id   # Security group ID
terraform output availability_zones_info         # AZ distribution details
```

## Cost Estimation

**Running Infrastructure:**
- VPC, Subnets, IGW, Route Tables: **FREE**
- Security Groups: **FREE**
- EC2 t2.micro (running): **~$0.01/hour** (~$7.30/month)
- EBS 25GB GP2: **~$2.50/month**
- Data transfer: **Variable** (first 1GB/month free)

**Total:** ~$10/month per environment when instance is running

**Cost Savings:**
- Terminate instances when not in use: `terraform destroy`
- Use Terraform to spin up/down as needed
- AMI storage: ~$0.05/GB/month (~$0.80/month for 16GB AMI)

## Author

**Dhruv Baraiya**  
Master's in Software Engineering Systems, Northeastern University  
Email: dhruvbaraiya27@gmail.com