variable "region" {
  default = "us-east-1"
}

variable "db_username" {
  default = "postgres"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  default = "videoclub"
}

variable "rds_identifier" {
  default = "videoclub-db"
}

variable "sqs_queue_name" {
  default = "rating-requests"
}

variable "cluster_sg_id" {
  description = "Security group ID del cluster para acceso a RDS"
  type        = string
}
