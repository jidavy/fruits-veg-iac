packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
  }
}

variable "region" {
  type    = string
  default = "eu-west-2"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "nginx" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"
  ami_name      = "fruits-nginx-${local.timestamp}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name = "fruits-nginx"
  }
}

build {
  name    = "nginx"
  sources = ["source.amazon-ebs.nginx"]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y nginx git",
      "sudo systemctl enable nginx",
      "git clone https://github.com/jidavy/fruits-veg_market.git /tmp/app",
      "sudo cp -r /tmp/app/web/* /usr/share/nginx/html/",
    ]
  }
}

source "amazon-ebs" "backend" {
  region        = var.region
  instance_type = "t3.micro"
  ssh_username  = "ec2-user"
  ami_name      = "fruits-backend-${local.timestamp}"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  tags = {
    Name = "fruits-backend"
  }
}

build {
  name    = "backend"
  sources = ["source.amazon-ebs.backend"]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y git python3 python3-pip java-17-amazon-corretto-devel maven",
      "sudo git clone https://github.com/jidavy/fruits-veg_market.git /opt/fruits-veg_market",
      "sudo chown -R ec2-user:ec2-user /opt/fruits-veg_market",
      "cd /opt/fruits-veg_market/python && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt",
      "cd /opt/fruits-veg_market/java && mvn -q -DskipTests package",
      "ls -l /opt/fruits-veg_market/java/target/",
      "/opt/fruits-veg_market/python/.venv/bin/uvicorn --version",
      "java -version",
    ]
  }
}
