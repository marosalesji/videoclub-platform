output "rds_endpoint" {
  value = aws_db_instance.videoclub.address
}

output "sqs_queue_url" {
  value = aws_sqs_queue.rating_requests.url
}

output "secret_name" {
  value = aws_secretsmanager_secret.rds.name
}
