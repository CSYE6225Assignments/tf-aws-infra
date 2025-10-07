# Data source to get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for AZ selection
locals {
  # Use provided AZs or auto-select first 3 available AZs in the region
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
}