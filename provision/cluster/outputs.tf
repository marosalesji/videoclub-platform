output "controller_public_ip" {
  value = aws_instance.controller.public_ip
}

output "worker_public_ip" {
  value = aws_instance.worker.public_ip
}

output "ssh_private_key" {
  value     = tls_private_key.ssh.private_key_pem
  sensitive = true
}

output "kubeconfig_hint" {
  value = "ssh ubuntu@${aws_instance.controller.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "cluster_sg_id" {
  value = aws_security_group.cluster.id
}
