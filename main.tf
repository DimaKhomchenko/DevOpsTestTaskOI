provider "aws" {
  region = "eu-north-1"
}
#----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_route_table" "selected" {
  vpc_id = aws_vpc.test_vpc.id
}
#----------------------------------------------------------------------------
resource "aws_vpc" "test_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Test_VPC"
  }
}

resource "aws_subnet" "test_subnet_a" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "192.168.101.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "Test_VPC_Subnet_A"
  }
}

resource "aws_subnet" "test_subnet_b" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "192.168.102.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "Test_VPC_Subnet_B"
  }
}

resource "aws_internet_gateway" "test_gw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "Test_GW_for_test_VPC"
  }
}

resource "aws_route" "internet_route" {
  route_table_id         = data.aws_route_table.selected.id
  gateway_id             = aws_internet_gateway.test_gw.id
  destination_cidr_block = "0.0.0.0/0"
}

#----------------------------------------------------------------------------
resource "aws_security_group" "http_https_ssh" {
  name        = "HTTP_HTTPS_SSH"
  description = "Allow HTTP HTTPS SSH"
  vpc_id      = aws_vpc.test_vpc.id

  dynamic "ingress" {
    for_each = ["22", "80", "443", "8080"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP HTTPS SSH"
  }
}
#----------------------------------------------------------------------------

resource "aws_launch_template" "test_docker_web_server" {
  name_prefix            = "TestDockerWebServerLT"
  instance_type          = "t3.micro"
  image_id               = data.aws_ami.latest_amazon_linux.image_id
  vpc_security_group_ids = [aws_security_group.http_https_ssh.id]
  user_data              = filebase64("external.sh")
}

resource "aws_autoscaling_group" "test_docker_web_server" {
  name_prefix = "TestDockerWebServerASG"
  launch_template {
    id      = aws_launch_template.test_docker_web_server.id
    version = "$Latest"
  }
  min_size            = 1
  max_size            = 1
  min_elb_capacity    = 1
  vpc_zone_identifier = [aws_subnet.test_subnet_a.id, aws_subnet.test_subnet_b.id]
  health_check_type   = "ELB"
  target_group_arns   = [aws_lb_target_group.test_ALB_TG.arn]

  tags = [
    {
      key                 = "Name"
      value               = "TestDockerWebServerInASG"
      propagate_at_launch = true
    }
  ]

  lifecycle {
    ignore_changes = [target_group_arns]
  }
}
#----------------------------------------------------------------------------
resource "aws_lb" "test_ALB" {
  name               = "TestALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.http_https_ssh.id]
  subnets            = [aws_subnet.test_subnet_a.id, aws_subnet.test_subnet_b.id]
}

resource "aws_lb_listener" "test_ALB_listener" {
  load_balancer_arn = aws_lb.test_ALB.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.test_ALB_TG.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "test_ALB_TG" {
  name                 = "TestALBTG"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.test_vpc.id
  deregistration_delay = 10

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = 8080
  }
}

output "ALB_URL" {
  value = aws_lb.test_ALB.dns_name
}
