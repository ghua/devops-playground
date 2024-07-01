output "wordpress_mysql_filesystem_id" {
  value       = aws_efs_file_system.wordpress_mysql_efs.id
  description = "Wordpress MySQL filesystem id"
}
