variable "region" {
  default = "us-east-1"
}

variable "allowed_ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "cluster_token" {
  description = "Token compartido entre controller y worker"
  default     = "super-secret-cluster-token"
}
