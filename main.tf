resource "aws_vpc" "metroDev" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "metroDev"
  }
}

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.metroDev.id
  cidr_block = var.ipv4_public_cidrs[0]
  availability_zone = "us-east-1a"

  tags = {
    Name = "metroDev"
  }
}

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.metroDev.id
  cidr_block = var.ipv4_public_cidrs[1]
  availability_zone = "us-east-1b"
  tags = {
    Name = "metroDev"
  }
}

resource "aws_internet_gateway" "metroDevIGW" {
  vpc_id = aws_vpc.metroDev.id

  tags = {
    Name = "metroDev"
  }
}


resource "aws_route_table" "metroDevRT" {
  vpc_id = aws_vpc.metroDev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.metroDevIGW.id
  }



  tags = {
    Name = "metroDev"
  }
}

resource "aws_route_table_association" "RTASSOA" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.metroDevRT.id
}

resource "aws_route_table_association" "RTASSOB" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.metroDevRT.id
}


data "aws_vpc" "metroDev" {
  default = true
}

resource "aws_security_group" "ec2_sg_tf" {
  name        = "ec2_sg_tf"
  description = "Allow port 22, 80 server"
  vpc_id      = data.aws_vpc.metroDev.id

  ingress {
    description = "HTTPS ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg_tf" {
  name        = "alb_sg_tf"
  description = "Allow port 80 for all"
  vpc_id      = aws_vpc.metroDev.id

  ingress {
    description = "HTTPS ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg_tf" {
  name        = "rds_sg_tf"
  description = "Allow port 3306 server"
  vpc_id      = data.aws_vpc.metroDev.id

  ingress {
    description = "HTTPS ingress"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical account ID
}

resource "aws_s3_bucket" "metrozikora" {
  bucket = "metrozikoraora"
  tags = {
    Name = "metros3"

  }
}

resource "aws_iam_role" "metro_role" {
  name = "metro_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

}

resource "aws_iam_policy" "s3policy" {
  name = "s3policy"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "S3:FullAccess",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::*"
      },
    ]
  })
}

resource "aws_launch_configuration" "metroLT" {
  name_prefix   = "metroLT"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "metroALG" {
  name                 = "metroALG"
  launch_configuration = aws_launch_configuration.metroLT.name
  min_size             = 2
  max_size             = 3
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "EC2"
  availability_zones        = ["us-east-1a", "us-east-1b"]
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "albTG-metro" {
  name        = "talb-metro"
  target_type = "ip"
  port        = 443
  protocol    = "HTTPS"
  vpc_id = aws_vpc.metroDev.id
}



resource "aws_lb" "lb" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_tf.id]
  subnets            = [
    aws_subnet.public1.id, 
    aws_subnet.public2.id
    ]
  

}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.albTG-metro.arn
  }
}
 