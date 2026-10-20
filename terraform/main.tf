terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "nginx" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["fruits-nginx-*"]
  }
}

data "aws_ami" "backend" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["fruits-backend-*"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "frontend" {
  name        = "fruits-frontend-sg"
  description = "Frontend: SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "HTTP"
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

resource "aws_security_group" "backend" {
  name        = "fruits-backend-sg"
  description = "Backends: SSH, Python 8080, Java 9090"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Python API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Java API"
    from_port   = 9090
    to_port     = 9090
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

resource "aws_instance" "python" {
  ami                         = data.aws_ami.backend.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.backend.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    cat > /etc/systemd/system/fruits-python.service <<UNIT
    [Unit]
    Description=Fruits API (FastAPI)
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/opt/fruits-veg_market/python
    ExecStart=/opt/fruits-veg_market/python/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8080
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now fruits-python
  EOT

  tags = {
    Name = "tf-python-backend"
  }
}

resource "aws_instance" "java" {
  ami                         = data.aws_ami.backend.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.backend.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    cat > /etc/systemd/system/fruits-java.service <<UNIT
    [Unit]
    Description=Veg API (Spring Boot)
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/opt/fruits-veg_market/java
    ExecStart=/usr/bin/java -jar /opt/fruits-veg_market/java/target/produce-app-0.0.1-SNAPSHOT.jar --server.address=0.0.0.0 --server.port=9090
    Restart=always

    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now fruits-java
  EOT

  tags = {
    Name = "tf-java-backend"
  }
}

resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.nginx.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOT
    #!/bin/bash
    sed -i "s/FRUIT_MACHINE:9000/${aws_instance.python.public_ip}:8080/; s/VEG_MACHINE:8080/${aws_instance.java.public_ip}:9090/" /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  tags = {
    Name = "tf-nginx-frontend"
  }
}