# ==================================================
# EC2 SUBMISSION SERVICE - OUTPUTS
# ==================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.submission.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.submission.public_ip
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.submission.private_ip
}

output "security_group_id" {
  description = "Security group ID of the EC2 instance"
  value       = aws_security_group.submission_ec2.id
}

output "instance_profile_arn" {
  description = "IAM instance profile ARN"
  value       = aws_iam_instance_profile.submission_ec2.arn
}

output "submission_service_url" {
  description = "URL to access submission service"
  value       = "http://${aws_instance.submission.public_ip}:5000"
}
