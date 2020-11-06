#Code to create AWS VPC and asked user to enter VPC CIDR Range and Name 
resource "aws_vpc" "web-vpc" {
  cidr_block  = "${var.vpc_cidr}"
  tags = {
    Name = "web-vpc"
  }
}


#Code to create Data Source of Public Subnet 
data "aws_subnet_ids" "public" {
  depends_on = ["aws_subnet.public"]
  vpc_id     = "${aws_vpc.web-vpc.id}"
  tags = {
    tier = "public"
  }
}

#Code to create Data Source of Private Subnet
data "aws_subnet_ids" "private" {
  depends_on = ["aws_subnet.private"]
  vpc_id     = "${aws_vpc.web-vpc.id}"
  tags = {
    tier = "private"
  }
}

#Code to create Public Subnet 
resource "aws_subnet" "public" {
  count             = "${length(var.public_subnets_cidr)}"
  vpc_id            = "${aws_vpc.web-vpc.id}"
  cidr_block        = "${element(var.public_subnets_cidr,count.index)}"
  availability_zone = "${element(var.azs,count.index)}"
  tags = {
    Name = "Public-Subnet-${count.index+1}"
    tier = "public"
  }
}

#Code to create Private Subnet 
resource "aws_subnet" "private" {
  count             = "${length(var.private_subnets_cidr)}"
  vpc_id            = "${aws_vpc.web-vpc.id}"
  cidr_block        = "${element(var.private_subnets_cidr,count.index)}"
#  map_public_ip_on_launch = "true"
  availability_zone = "${element(var.azs,count.index)}"
  tags = {
    Name = "Private-Subnet-${count.index+1}"
    tier = "private"
  }
}

#Code to create Internet Gateway 
resource "aws_internet_gateway" "web_igw" {
  vpc_id = "${aws_vpc.web-vpc.id}"
  tags = {
    Name = "main"
  }
}

#To create public route table
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.web-vpc.id}"
  tags = {
    Name = "public_route_table_main"
  }
}

# Add Public Internet gateway to the route table
resource "aws_route" "public" {
  gateway_id             = "${aws_internet_gateway.web_igw.id}"
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = "${aws_route_table.public.id}"
}

#Associate Public route table as main route table
resource "aws_main_route_table_association" "public" {
  vpc_id         = "${aws_vpc.web-vpc.id}"
  route_table_id = "${aws_route_table.public.id}"
}

# Associate Public route table with each public subnet
resource "aws_route_table_association" "public" {
  count          = "${length(var.azs)}"
  subnet_id      = "${element(aws_subnet.public.*.id,count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

# create elastic IP (EIP) to assign it the NAT Gateway
resource "aws_eip" "web_eip" {
  count      = "${length(var.azs)}"
  vpc        = true
  depends_on = ["aws_internet_gateway.web_igw"]
}

# create NAT Gateways
# make sure to create the nat in a internet-facing subnet (public subnet)
resource "aws_nat_gateway" "web-nat" {
    count         = "${length(var.azs)}"
    allocation_id = "${element(aws_eip.web_eip.*.id, count.index)}"
    subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
    depends_on    = ["aws_internet_gateway.web_igw"]
}

#To Create Private route table's
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.web-vpc.id}"
  count  = "${length(var.azs)}" 
  tags = { 
    Name = "private_subnet_route_table_${count.index}"
  }
}

# Add a nat gateway to each private subnet's route table
resource "aws_route" "private_nat_gateway_route" {
  count                  = "${length(var.azs)}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  depends_on             = ["aws_route_table.private"]
  nat_gateway_id         = "${element(aws_nat_gateway.web-nat.*.id, count.index)}"
}

# Associate Private route table with each private subnet
resource "aws_route_table_association" "private" {
  count          = "${length(var.azs)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

#To create Application Load Balancer Security Group to allow 80 an 443 TCP Traffic
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "allow incoming 80 and 443 TCP traffic only"
  vpc_id      = "${aws_vpc.web-vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-security-group"
  }
}

# security group for Web-server EC2 instances which allow 80 and 22 TCP Traffic 
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "allow incoming HTTP traffic only"
  vpc_id      = "${aws_vpc.web-vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "web-security-group"
  }
}

