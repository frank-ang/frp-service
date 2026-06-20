output "elastic_ip" {
  description = "The static Elastic IP address that is kept attached to the current live instance."
  value       = aws_eip.this.public_ip
}

output "elastic_ip_allocation_id" {
  value = aws_eip.this.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.this.name
}

output "launch_template_id" {
  value = aws_launch_template.this.id
}

output "security_group_id" {
  value = aws_security_group.instance.id
}

output "iam_role_arn" {
  value = aws_iam_role.instance.arn
}

output "ami_id" {
  description = "Ubuntu 24.04 LTS AMI used by the launch template."
  value       = data.aws_ami.ubuntu.id
}
