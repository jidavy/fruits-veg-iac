output "nginx_ami_id" {
  value = data.aws_ami.nginx.id
}

output "backend_ami_id" {
  value = data.aws_ami.backend.id
}