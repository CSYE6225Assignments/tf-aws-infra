# AWS Networking Infrastructure with Terraform

## Overview
This project automates the setup of AWS networking resources using Terraform.  
It creates a Virtual Private Cloud (VPC) with public and private subnets, Internet Gateway, and route tables as per assignment requirements.  
All configurations are parameterized using `.tfvars` files—no hardcoded values are used.

## Features
- One VPC per environment (dev, demo, etc.)
- 3 Public and 3 Private subnets across 3 Availability Zones
- Internet Gateway attached to VPC
- Public route to Internet Gateway (0.0.0.0/0)
- Separate public and private route tables
- Dynamic AZ distribution (round-robin logic)
- Works across multiple regions without conflict
- GitHub Actions CI for terraform fmt and validate checks

## Files Included
```
main.tf
variables.tf
outputs.tf
dev.tfvars
demo.tfvars
second-vpc.tfvars
west.tfvars
.github/workflows/terraform-ci.yml
```

## Prerequisites
- AWS CLI configured with `dev` and `demo` profiles
- Terraform v1.0+
- jq (for JSON query verification)

## AWS CLI Setup
```bash
aws configure --profile dev
aws configure --profile demo
aws sts get-caller-identity --profile dev
aws sts get-caller-identity --profile demo
```

## Terraform Commands

### Initialize and Validate
```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

### Apply Infrastructure
```bash
export AWS_PROFILE=dev
terraform apply -auto-approve -var-file=dev.tfvars
```

### Verify Setup
```bash
# Check all non-default VPCs
aws ec2 describe-vpcs --filters Name=isDefault,Values=false --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}'

# Verify public route has IGW
aws ec2 describe-route-tables --route-table-ids $(terraform output -raw public_route_table_id) --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`]'

# Verify subnet distribution (3 AZs)
aws ec2 describe-subnets --subnet-ids $(terraform output -json public_subnet_ids | jq -r '.[]' | xargs) --query 'Subnets[].AvailabilityZone' | jq 'unique | length'
```

### Destroy Infrastructure
```bash
terraform destroy -auto-approve -var-file=dev.tfvars
terraform destroy -auto-approve -var-file=demo.tfvars
terraform destroy -auto-approve -var-file=second-vpc.tfvars
terraform destroy -auto-approve -var-file=west.tfvars
```

## Continuous Integration
GitHub Actions Workflow (`.github/workflows/terraform-ci.yml`) runs:
- `terraform fmt -check -recursive`
- `terraform validate`

Branch protection ensures merges only when CI passes.

## Author
**Dhruv Baraiya**  
Master’s in Software Engineering Systems, Northeastern University  
Email: dhruvbaraiya27@gmail.com
