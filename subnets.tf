# Create Public Subnets (3 subnets in different AZs)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-subnet-${count.index + 1}"
    Type        = "Public"
    Environment = var.environment
  }
}

# Create Private Subnets (3 subnets in different AZs)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name        = "${var.vpc_name}-private-subnet-${count.index + 1}"
    Type        = "Private"
    Environment = var.environment
  }
}