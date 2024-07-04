output "wordpress_mysql_filesystem_id" {
  value       = aws_efs_file_system.wordpress_mysql_efs.id
  description = "Wordpress MySQL filesystem id"
}

output "wordpress_filesystem_id" {
  value       = aws_efs_file_system.wordpress_efs.id
  description = "Wordpress filesystem id"
}

output "mysql_root_password" {
  value = var.mysql_password
}
