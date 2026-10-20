output "nginx_ami_id" {
  value = data.aws_ami.nginx.id
}

output "backend_ami_id" {
  value = data.aws_ami.backend.id
}

output "frontend_url" {
  value = "http://${aws_instance.frontend.public_ip}"
}

output "python_url" {
  value = "http://${aws_instance.python.public_ip}:8080/fruits"
}

output "java_ip" {
  value = aws_instance.java.public_ip
}